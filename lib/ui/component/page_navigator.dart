/*
 * Copyright 2023 Hongen Wang
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
import 'package:proxypin/network/components/manager/request_breakpoint_manager.dart';
import 'package:proxypin/network/components/manager/request_rewrite_manager.dart';
import 'package:proxypin/network/http/http.dart';
import 'package:proxypin/network/util/logger.dart';
import 'package:proxypin/ui/mobile/debug/breakpoint_executor.dart';
import 'package:proxypin/ui/mobile/setting/request_breakpoint.dart';
import 'package:proxypin/ui/mobile/setting/request_crypto.dart';
import 'package:proxypin/ui/mobile/setting/request_map.dart';
import 'package:proxypin/ui/mobile/setting/request_rewrite.dart';
import 'package:proxypin/ui/mobile/setting/script.dart';
import 'package:proxypin/ui/toolbox/aes_page.dart';
import 'package:proxypin/ui/toolbox/cert_hash.dart';
import 'package:proxypin/ui/toolbox/encoder.dart';
import 'package:proxypin/ui/toolbox/js_run.dart';
import 'package:proxypin/ui/toolbox/json_viewer.dart';
import 'package:proxypin/ui/toolbox/qr_code_page.dart';
import 'package:proxypin/ui/toolbox/regexp.dart';
import 'package:proxypin/ui/toolbox/text_diff.dart';
import 'package:proxypin/ui/toolbox/text_editor.dart';
import 'package:proxypin/ui/toolbox/timestamp.dart';
import 'package:proxypin/ui/toolbox/websocket_request.dart';
import 'package:proxypin/ui/toolbox/xml_viewer.dart';
import 'package:proxypin/utils/navigator.dart';

/// 页面跳转桥接（安卓手机版）。
///
/// 桌面版通过 desktop_multi_window 打开独立窗口，手机版统一为 [Navigator] 推入新页面。
/// 网络层（如断点拦截）没有 BuildContext，故统一走 [NavigatorHelper] 的全局 navigatorKey。
///
/// @author wanghongen
class PageNavigator {
  /// 按名称把页面推入导航栈
  static Future<void> open(String widgetName, {Map<String, dynamic>? args}) async {
    var page = await build(widgetName, args);
    if (page == null) return;
    await NavigatorHelper.push(MaterialPageRoute(builder: (context) => page));
  }

  /// 按名称构建页面（无匹配返回 null）
  static Future<Widget?> build(String widgetName, Map<String, dynamic>? args) async {
    args ??= const {};
    switch (widgetName) {
      //脚本
      case 'ScriptWidget':
        return const MobileScript();
      //请求重写
      case 'RequestRewriteWidget':
        return MobileRequestRewrite(requestRewrites: await RequestRewriteManager.instance);
      // 请求加密
      case 'RequestCryptoPage':
        return const MobileRequestCryptoPage();
      // 请求映射
      case 'RequestMapPage':
        return const MobileRequestMapPage();
      // 请求拦截
      case 'RequestBreakpointPage':
        return MobileRequestBreakpointPage(manager: await RequestBreakpointManager.instance);
      case 'QrCodePage':
        return const QrCodePage();
      case 'JsonViewerPage':
        return const JsonViewerPage();
      case 'XmlViewerPage':
        return const XmlViewerPage();
      case 'TextDiffPage':
        return const TextDiffPage();
      case 'TextEditorPage':
        return const TextEditorPage();
      case 'CertHashPage':
        return const CertHashPage();
      case 'JavaScript':
        return const JavaScript();
      case 'RegExpPage':
        return const RegExpPage();
      case 'TimestampPage':
        return const TimestampPage();
      case 'AesPage':
        return AesPage(text: args['text']);
      case 'WebSocketRequestPage':
        return const WebSocketRequestPage();
      //断点执行器
      case 'BreakpointExecutor':
        return BreakpointExecutor(
          request: HttpRequest.fromJson(args['request']),
          response: args['response'] == null ? null : HttpResponse.fromJson(args['response']),
          isResponse: args['type'] == 'response',
          requestId: args['requestId'],
        );
    }
    logger.w('Unknown page name: $widgetName');
    return null;
  }
}

///打开编码页面
Future<void> encodeWindow(EncoderType type, BuildContext context, [String? text]) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (context) => EncoderWidget(type: type, text: text)));
}

///打开 AES 页面
Future<void> openAesWindow(BuildContext context, String text) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (context) => AesPage(text: text)));
}
