/*
 * Copyright 2026 Hongen Wang All rights reserved.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 轻量 MCP Streamable HTTP 客户端（仅用于本机/局域网连通性自检）。
///
/// 与 [McpHttpServer] 的无状态协议对齐：单 JSON 请求 / 单 JSON（或 SSE 单帧）响应，
/// 支持可选的 `Authorization: Bearer <token>`。用于手机本地 MCP 连接页验证
/// 「本机的 AI 客户端能不能连上 ProxyPin 的 MCP 服务」。
///
/// @author wanghongen
class McpClient {
  static const String protocolVersion = '2025-03-26';

  final Uri endpoint;
  final String? token;
  final Duration timeout;

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 3);

  int _nextId = 1;

  McpClient({required this.endpoint, this.token, this.timeout = const Duration(seconds: 5)});

  /// 连接本机 MCP 服务（默认 http://127.0.0.1:<port>/mcp）
  factory McpClient.local(int port, {String? token, String host = '127.0.0.1'}) {
    return McpClient(endpoint: Uri.parse('http://$host:$port/mcp'), token: token);
  }

  /// 依次完成 initialize + tools/list，返回可读的连接结果。
  Future<McpPingResult> ping() async {
    var sw = Stopwatch()..start();
    var init = await _rpc('initialize', {
      'protocolVersion': protocolVersion,
      'capabilities': const {},
      'clientInfo': {'name': 'proxypin-mobile-client', 'version': '1.0'},
    });
    var serverInfo = init['serverInfo'];
    var info = serverInfo is Map
        ? {'name': serverInfo['name'], 'version': serverInfo['version']}
        : const <String, dynamic>{};
    var tools = <String>[];
    try {
      var listed = await _rpc('tools/list', const {});
      var list = listed['tools'];
      if (list is List) {
        for (var t in list) {
          if (t is Map && t['name'] != null) tools.add(t['name'].toString());
        }
      }
    } catch (_) {
      // 服务器未实现 tools/list 时不算失败，仍视为连接成功
    }
    sw.stop();
    return McpPingResult(
      ok: true,
      latencyMs: sw.elapsedMilliseconds,
      protocolVersion: init['protocolVersion']?.toString(),
      serverInfo: info,
      tools: tools,
    );
  }

  Future<Map<String, dynamic>> _rpc(String method, Map<String, dynamic> params) async {
    var payload = {
      'jsonrpc': '2.0',
      'id': _nextId++,
      'method': method,
      'params': params,
    };
    var body = await _post(payload);
    if (body.containsKey('error')) {
      var err = body['error'];
      var msg = err is Map ? err['message']?.toString() : '$err';
      throw McpClientException('MCP error: $msg');
    }
    var result = body['result'];
    return result is Map<String, dynamic> ? result : Map<String, dynamic>.from(result as Map);
  }

  Future<Map<String, dynamic>> _post(Map<String, dynamic> payload) async {
    HttpClientRequest? req;
    try {
      req = await _httpClient.postUrl(endpoint).timeout(timeout);
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.acceptHeader, 'application/json, text/event-stream');
      if (token != null && token!.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      req.write(jsonEncode(payload));
      var resp = await req.close().timeout(timeout);
      var text = await resp.transform(utf8.decoder).join().timeout(timeout);
      if (resp.statusCode >= 400) {
        throw McpClientException('HTTP ${resp.statusCode}: ${_brief(text)}');
      }
      var decoded = _parseBody(resp.headers.contentType, text);
      if (decoded == null) throw McpClientException('empty response');
      return decoded;
    } on McpClientException {
      rethrow;
    } on SocketException catch (e) {
      throw McpClientException('cannot connect: ${e.osError?.message ?? e.message}');
    } on TimeoutException {
      throw McpClientException('timeout (${timeout.inSeconds}s)');
    } finally {
      req = null;
    }
  }

  /// 同时支持 application/json 与 text/event-stream（取首个 data: 帧）
  Map<String, dynamic>? _parseBody(ContentType? contentType, String text) {
    if (text.trim().isEmpty) return null;
    if (contentType?.mimeType == 'text/event-stream') {
      for (var line in const LineSplitter().convert(text)) {
        if (line.startsWith('data:')) {
          var json = line.substring(5).trim();
          if (json.isEmpty) continue;
          var obj = jsonDecode(json);
          if (obj is Map<String, dynamic>) return obj;
        }
      }
      return null;
    }
    var obj = jsonDecode(text);
    return obj is Map<String, dynamic> ? obj : null;
  }

  static String _brief(String text) => text.length > 160 ? '${text.substring(0, 160)}…' : text;

  void dispose() {
    _httpClient.close(force: true);
  }
}

class McpPingResult {
  final bool ok;
  final int latencyMs;
  final String? protocolVersion;
  final Map<String, dynamic> serverInfo;
  final List<String> tools;

  McpPingResult({
    required this.ok,
    required this.latencyMs,
    this.protocolVersion,
    required this.serverInfo,
    required this.tools,
  });
}

class McpClientException implements Exception {
  final String message;

  McpClientException(this.message);

  @override
  String toString() => message;
}