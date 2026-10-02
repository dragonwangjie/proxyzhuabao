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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:proxypin/l10n/app_localizations.dart';
import 'package:proxypin/mcp/mcp_names.dart';
import 'package:proxypin/mcp/mcp_service.dart';
import 'package:proxypin/mcp/transport/mcp_client.dart';
import 'package:proxypin/network/bin/server.dart';
import 'package:proxypin/ui/component/port_edit_dialog.dart';
import 'package:proxypin/ui/configuration.dart';
import 'package:proxypin/ui/mobile/mobile.dart';

/// 手机本地 MCP 连接：在 127.0.0.1 上暴露 MCP HTTP 服务（无鉴权），
/// 供手机上的 AI 客户端（或经 `adb forward` 转发到电脑）直接连接本机调试；
/// 并提供内置 MCP 客户端做连接自检（initialize + tools/list）。
///
/// @author wanghongen
class MobileMcpLocalSetting extends StatefulWidget {
  final ProxyServer proxyServer;

  const MobileMcpLocalSetting({super.key, required this.proxyServer});

  @override
  State<MobileMcpLocalSetting> createState() => _MobileMcpLocalSettingState();
}

class _MobileMcpLocalSettingState extends State<MobileMcpLocalSetting> {
  final AppConfiguration cfg = AppConfiguration.current!;

  bool _busy = false;
  String? _error;

  bool _testing = false;
  McpPingResult? _pingResult;
  String? _pingError;

  AppLocalizations get l => AppLocalizations.of(context)!;

  /// 本地页面新文案暂用内联双语（升级公告同样处理方式），避免手改生成的 l10n 文件
  String _t(String zh, String en) => Localizations.localeOf(context).languageCode == 'zh' ? zh : en;

  bool get _running => McpService.instance.isLocalRunning;

  int get _effectivePort => McpService.instance.localPort ?? cfg.mcpLocalPort ?? McpService.defaultLocalPort;

  String get _endpoint => 'http://127.0.0.1:$_effectivePort/mcp';

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _toggle(bool enabled) async {
    setState(() {
      _busy = true;
      _error = null;
      if (!enabled) {
        _pingResult = null;
        _pingError = null;
      }
    });
    cfg.mcpLocalEnabled = enabled;
    if (enabled) {
      McpService.instance.attach(widget.proxyServer, existing: MobileApp.container.source);
    }
    try {
      if (enabled) {
        await McpService.instance.startLocal(cfg);
      } else {
        await McpService.instance.stopLocal();
      }
    } catch (e) {
      cfg.mcpLocalEnabled = false;
      _error = '${l.mcpStartFailed}: $e';
    }
    cfg.flushConfig();
    if (mounted) setState(() => _busy = false);
  }

  /// 修改本地监听端口：校验通过后写入配置，运行中则重启服务使新端口生效
  Future<void> _editPort() async {
    var newPort = await PortEditDialog.show(
      context,
      initialPort: cfg.mcpLocalPort ?? McpService.defaultLocalPort,
      defaultPort: McpService.defaultLocalPort,
    );
    if (newPort == null || newPort == (cfg.mcpLocalPort ?? McpService.defaultLocalPort)) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    cfg.mcpLocalPort = newPort;
    cfg.flushConfig();
    try {
      if (_running) {
        await McpService.instance.stopLocal();
        // stopLocal() 可能清空抓包索引，重启前回填当前列表
        McpService.instance.attach(widget.proxyServer, existing: MobileApp.container.source);
        await McpService.instance.startLocal(cfg);
      }
    } catch (e) {
      _error = '${l.mcpStartFailed}: $e';
    }
    if (mounted) setState(() => _busy = false);
  }

  /// 内置客户端连接自检：本机 loopback 直连刚启动的 MCP 服务
  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _pingResult = null;
      _pingError = null;
    });
    var client = McpClient.local(_effectivePort);
    try {
      var result = await client.ping();
      if (mounted) setState(() => _pingResult = result);
    } on McpClientException catch (e) {
      if (mounted) setState(() => _pingError = e.message);
    } catch (e) {
      if (mounted) setState(() => _pingError = '$e');
    } finally {
      client.dispose();
      if (mounted) setState(() => _testing = false);
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l.mcpCopied), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    var theme = Theme.of(context);
    var cs = theme.colorScheme;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(42),
        child: AppBar(
          title: Text(_t('本地 MCP 连接', 'Local MCP Connection'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
          centerTitle: true,
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        _card([
          SwitchListTile(
            value: _running,
            onChanged: _busy ? null : _toggle,
            activeThumbColor: cs.primary,
            title: Text(_t('启用本地连接', 'Enable local connection'), style: const TextStyle(fontSize: 14)),
            subtitle: Text(
              _t('在本机 127.0.0.1 上启动 MCP 服务（无鉴权），手机内的 AI 客户端可直接连接；'
                  '也可用 adb forward 把端口转发到电脑。',
                  'Serve MCP on 127.0.0.1 (no auth) so AI clients on this phone can connect directly. '
                      'You can also forward the port to a computer via adb forward.'),
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
            ),
          ),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: _statusRow(cs),
          ),
        ]),
        const SizedBox(height: 12),
        if (_running) ...[
          _card([
            ListTile(
              dense: true,
              leading: Icon(Icons.phone_android_rounded, color: cs.primary),
              title: Text(l.mcpEndpoint, style: const TextStyle(fontSize: 14)),
              subtitle: SelectableText(
                _endpoint,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: l.edit,
                  icon: const Icon(Icons.edit_rounded, size: 19),
                  onPressed: _busy ? null : _editPort,
                ),
                IconButton(
                  icon: const Icon(Icons.copy_all_rounded, size: 19),
                  onPressed: () => _copy(_endpoint),
                ),
              ]),
            ),
            Divider(height: 0, thickness: 0.3, color: theme.dividerColor.withValues(alpha: 0.22)),
            ListTile(
              dense: true,
              leading: Icon(Icons.network_check_rounded, color: cs.primary),
              title: Text(_t('连接自检', 'Connection test'), style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                _t('用内置 MCP 客户端访问本机服务，验证 initialize 与 tools/list。',
                    'Use the built-in MCP client to hit the local server (initialize + tools/list).'),
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, height: 1.4),
              ),
              trailing: _testing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : FilledButton.tonal(
                      onPressed: _testConnection,
                      child: Text(_t('测试', 'Test'), style: const TextStyle(fontSize: 12.5)),
                    ),
            ),
            if (_pingResult != null || _pingError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _pingResult != null ? _pingSuccess(_pingResult!, cs) : _pingFailure(cs),
              ),
          ]),
          const SizedBox(height: 12),
          _card([
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(_t('如何连接', 'How to connect'),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: cs.primary)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                _t('手机内的应用（Termux / 支持 MCP 的本地 AI 客户端）直接使用下面的 Streamable HTTP 地址，无需令牌：',
                    'Apps on this phone (Termux / local MCP-capable AI clients) can use the Streamable HTTP '
                        'endpoint below without a token:'),
                style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant),
              ),
            ),
            _commandBlock(cs, 'HTTP', _endpoint),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Text(
                _t('把端口转发到电脑（USB 连接手机后在电脑上执行）：',
                    'Forward the port to your computer (phone connected over USB):'),
                style: TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant),
              ),
            ),
            _commandBlock(cs, 'adb', 'adb forward tcp:$_effectivePort tcp:$_effectivePort'),
            _commandBlock(cs, 'Claude Code', _claudeCommand()),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
              child: Text(
                _t('本地模式不做鉴权：只有本机的进程（或 adb 转发的电脑）可以访问。'
                    '需要跨设备接入请改用「MCP 服务」中的局域网模式（带令牌）。',
                    'Local mode has no auth: only processes on this phone (or a computer via adb forward) can reach it. '
                        'For cross-device access, use the LAN mode with a token in “MCP Server”.'),
                style: TextStyle(fontSize: 11, height: 1.5, color: cs.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: InkWell(
                onTap: () => _copy(_genericHttpConfig()),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Icon(Icons.copy_all_rounded, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(l.mcpOtherClients,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.primary)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.error_outline_rounded, size: 17, color: cs.error),
              const SizedBox(width: 8),
              Expanded(
                  child: Text(_error!,
                      style: TextStyle(fontSize: 12, color: cs.onErrorContainer, height: 1.4))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _statusRow(ColorScheme cs) {
    var color = _running ? const Color(0xFF34C759) : cs.onSurfaceVariant;
    var icon = _running ? Icons.check_circle_rounded : Icons.cancel_outlined;
    var label = _running ? l.mcpStatusRunning : l.mcpStatusStopped;
    return Row(children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: color)),
    ]);
  }

  Widget _pingSuccess(McpPingResult r, ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.verified_rounded, size: 17, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _t('连接成功 · ${r.latencyMs}ms', 'Connected · ${r.latencyMs}ms'),
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.primary),
            ),
          ),
        ]),
        const SizedBox(height: 6),
        Text(
          'server: ${r.serverInfo['name'] ?? '?'} ${r.serverInfo['version'] ?? ''}   '
          'protocol: ${r.protocolVersion ?? '?'}   tools: ${r.tools.length}',
          style: TextStyle(fontSize: 11.5, height: 1.5, fontFamily: 'monospace', color: cs.onSurfaceVariant),
        ),
        if (r.tools.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(r.tools.join(' · '),
                style: TextStyle(fontSize: 11, height: 1.5, color: cs.onSurfaceVariant)),
          ),
      ]),
    );
  }

  Widget _pingFailure(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.link_off_rounded, size: 17, color: cs.error),
        const SizedBox(width: 8),
        Expanded(
            child: SelectableText(_pingError ?? '',
                style: TextStyle(fontSize: 12, color: cs.onErrorContainer, height: 1.4))),
      ]),
    );
  }

  Widget _card(List<Widget> children) {
    var theme = Theme.of(context);
    return Card(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
          side: BorderSide(color: theme.dividerColor.withValues(alpha: 0.13)),
          borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  String _claudeCommand() {
    return 'claude mcp add ${McpClientNames.mobile} --transport http "$_endpoint"';
  }

  /// 通用 Streamable HTTP 配置（本机直连，无 header）
  String _genericHttpConfig() {
    return '{\n'
        '  "mcpServers": {\n'
        '    "${McpClientNames.mobile}": {\n'
        '      "type": "http",\n'
        '      "url": "$_endpoint"\n'
        '    }\n'
        '  }\n'
        '}';
  }

  Widget _commandBlock(ColorScheme cs, String name, String command) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: cs.primary)),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _copy(command),
            icon: const Icon(Icons.copy_all_rounded, size: 15),
            label: Text(l.mcpCopy, style: const TextStyle(fontSize: 12.5)),
          ),
        ]),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(command,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5, height: 1.4)),
        ),
      ]),
    );
  }
}