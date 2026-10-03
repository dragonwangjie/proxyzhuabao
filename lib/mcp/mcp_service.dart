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

import 'dart:io';
import 'dart:math';

import 'package:proxypin/mcp/capture/flow_store.dart';
import 'package:proxypin/mcp/capture/history_provider.dart';
import 'package:proxypin/mcp/protocol/mcp_actions.dart';
import 'package:proxypin/mcp/protocol/mcp_server.dart';
import 'package:proxypin/mcp/transport/mcp_http_server.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/storage/histories.dart';
import 'package:proxypin/ui/configuration.dart';

/// MCP 服务编排：挂载抓包索引、启停本地 HTTP 传输。
///
/// 作为 [EventListener] 挂到 [ProxyServer.listeners]，与 UI 同源接收流量，
/// 因而平台无关且不依赖具体列表容器。
///
/// 安卓手机版提供两种连接模式（同时开启时共用同一份抓包索引）：
///  - 局域网模式：绑定 0.0.0.0 并要求 Bearer token，供同一 Wi-Fi 下电脑上的
///    AI 客户端（Claude Code / Codex 等）远程连接；
///  - 本地连接模式：绑定 127.0.0.1 且不做鉴权，供手机上（或经 adb 端口转发
///    到电脑上的）AI 客户端直接访问 `http://127.0.0.1:<localPort>/mcp`。
///
/// 优先固定端口（可经 cfg.mcpPort / cfg.mcpLocalPort 自定义），被占用时才回退到
/// 系统随机端口，保证 AI 客户端一次配置、重启 App 后无需改动。
///
/// @author wanghongen
class McpService {
  static final McpService instance = McpService._();

  McpService._();

  /// 默认局域网监听端口；可经 cfg.mcpPort 自定义，被占用时回退随机端口。
  static const int defaultPort = 9127;

  /// 默认本地(loopback)监听端口；可经 cfg.mcpLocalPort 自定义。
  static const int defaultLocalPort = 9128;

  FlowStore? _store;
  McpServer? _mcp;
  McpHttpServer? _http;
  McpHttpServer? _localHttp;
  ProxyServer? _attachedServer;

  /// 桥接 HistoryStorage 的历史数据源（lazy，与 FlowStore 同生命周期）
  late final HistoryProvider _historyProvider = _HistoryStorageBridge();

  FlowStore _createStore() => FlowStore(historyProvider: _historyProvider);

  /// 串行化 start/stop，避免自动启动与手动开关并发时重复 bind 端口
  Future<void>? _transitionLock;

  Future<void> _synchronized(Future<void> Function() action) {
    var previous = _transitionLock ?? Future<void>.value();
    var next = previous.then((_) => action());
    // 单次失败不能让后续操作永远拿不到锁
    _transitionLock = next.catchError((_) {});
    return next;
  }

  /// 由 UI 层注册：清空界面抓包列表（MCP clear_session 时一并触发）
  Future<void> Function()? clearUiSession;

  /// 局域网模式是否在运行
  bool get isRunning => _http?.isRunning ?? false;

  /// 本地连接（loopback）模式是否在运行
  bool get isLocalRunning => _localHttp?.isRunning ?? false;

  int? get port => _http?.port;

  int? get localPort => _localHttp?.port;

  /// 局域网模式的访问 token；本地 loopback 模式不用
  String? get token => _http?.token;

  /// 生成 48 位十六进制随机 token
  static String generateToken() {
    var random = Random.secure();
    return List.generate(24, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  /// 注册抓包索引到代理服务（幂等）。[existing] 用于启用时一次性回填已抓到的请求。
  void attach(ProxyServer server, {Iterable<HttpRequest>? existing}) {
    _store ??= _createStore();
    _attachedServer = server;
    if (!server.listeners.contains(_store)) {
      server.addListener(_store!);
    }
    if (existing != null && existing.isNotEmpty) {
      _store!.backfill(existing);
    }
  }

  McpServer _buildServer(AppConfiguration cfg) {
    var actions = McpActions(
      store: _store!,
      onClearSession: () async => clearUiSession?.call(),
      redactEnabled: () => cfg.mcpRedactEnabled,
    );
    return McpServer(
      store: _store!,
      redactEnabled: () => cfg.mcpRedactEnabled,
      extraTools: actions.tools(),
    );
  }

  /// 按当前配置启动局域网服务（必要时先挂到已存在的代理服务）。串行执行，避免并发重复绑定。
  Future<void> start(AppConfiguration cfg) => _synchronized(() => _startLanLocked(cfg));

  Future<void> _startLanLocked(AppConfiguration cfg) async {
    if (isRunning) return;

    var proxyServer = _attachedServer ?? ProxyServer.current;
    if (proxyServer != null) {
      attach(proxyServer);
    }
    _store ??= _createStore();
    _mcp ??= _buildServer(cfg);

    // 移动端绑 0.0.0.0 供局域网 AI 客户端连接，并要求 Bearer token。
    var token = (cfg.mcpToken?.isNotEmpty ?? false) ? cfg.mcpToken : generateToken();
    cfg.mcpToken = token;
    _http = McpHttpServer(mcp: _mcp!, address: InternetAddress.anyIPv4, token: token);

    await _bind(_http!, cfg.mcpPort ?? defaultPort, 'MCP');
  }

  /// 启动本地连接（loopback）服务：只监听 127.0.0.1、不做鉴权。
  Future<void> startLocal(AppConfiguration cfg) => _synchronized(() => _startLocalLocked(cfg));

  Future<void> _startLocalLocked(AppConfiguration cfg) async {
    if (isLocalRunning) return;

    var proxyServer = _attachedServer ?? ProxyServer.current;
    if (proxyServer != null) {
      attach(proxyServer);
    }
    _store ??= _createStore();
    // 本地模式独立 McpServer 实例（与局域网实例共享同一 FlowStore）
    var localServer = _buildServer(cfg);
    _localHttp = McpHttpServer(mcp: localServer, address: InternetAddress.loopbackIPv4);

    await _bind(_localHttp!, cfg.mcpLocalPort ?? defaultLocalPort, 'MCP(local)');
  }

  Future<void> _bind(McpHttpServer http, int preferredPort, String tag) async {
    try {
      try {
        await http.start(preferredPort);
      } on SocketException catch (e) {
        logger.w('$tag port $preferredPort unavailable, falling back to a random port: $e');
        await http.start(0);
      }
      logger.i('$tag service started on ${http.address.address}:${http.port}');
    } catch (e) {
      logger.e('$tag service start failed: $e');
      if (identical(http, _http)) _http = null;
      if (identical(http, _localHttp)) _localHttp = null;
      rethrow;
    }
  }

  Future<void> stop() => _synchronized(() async {
        await _stopLanLocked();
        await _stopLocalLocked();
      });

  /// 仅停止局域网服务（本地服务不受影响）
  Future<void> stopLan() => _synchronized(_stopLanLocked);

  /// 仅停止本地连接服务
  Future<void> stopLocal() => _synchronized(_stopLocalLocked);

  Future<void> _stopLanLocked() async {
    if (_http == null) return;
    await _http?.stop();
    _http = null;
    _mcp = null;
    await _releaseStoreIfIdle();
  }

  Future<void> _stopLocalLocked() async {
    if (_localHttp == null) return;
    await _localHttp?.stop();
    _localHttp = null;
    await _releaseStoreIfIdle();
  }

  /// 两种模式都停止后：解绑抓包监听并清空索引，避免停用期间抓到的敏感请求
  /// 在下次开启时被客户端读到；同时避免 start/stop 反复切换造成监听器堆积。
  Future<void> _releaseStoreIfIdle() async {
    if (isRunning || isLocalRunning || _store == null) return;
    _attachedServer?.removeListener(_store!);
    _store!.clear();
  }
}

/// 桥接 [HistoryStorage] 为 [HistoryProvider]。
///
/// 放在编排层，避免 mcp 核心直接依赖历史存储及其平台插件。请求列表的懒加载/缓存
/// 由 [HistoryStorage.getRequests] 自身保证（缓存在 HistoryItem.requests）。
class _HistoryStorageBridge implements HistoryProvider {
  @override
  Future<List<HistoryMeta>> list() async {
    var storage = await HistoryStorage.instance;
    var histories = storage.histories;
    return [
      for (var history in histories)
        HistoryMeta(
          id: history.stableId,
          name: history.name,
          requestCount: history.requestLength,
          fileSize: history.fileSize,
          createTimeMs: history.createTime.millisecondsSinceEpoch,
        )
    ];
  }

  @override
  Future<List<HttpRequest>> requests(int id) async {
    var storage = await HistoryStorage.instance;
    HistoryItem? history;
    for (var item in storage.histories) {
      if (item.stableId == id) {
        history = item;
        break;
      }
    }
    if (history == null) throw ArgumentError('history not found: $id');
    // 不写入 HistoryItem 永久缓存：报文只由 FlowStore 的 LRU 有界持有
    return await storage.readRequests(history);
  }
}