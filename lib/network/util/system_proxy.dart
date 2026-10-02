/*
 * Copyright 2023 Hongen Wang All rights reserved.
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

import 'package:proxypin/network/channel/host_port.dart';

/// @author wanghongen
/// 2023/7/26
///
/// 安卓手机版：出网流量由内置 VPN 服务接管（见 lib/native/vpn.dart），
/// 无需操作系统的代理开关。原桌面端（Windows/macOS/Linux）的系统代理实现已移除，
/// 这里仅保留被配置与代理内核引用的接口（空实现），保证既有配置项继续可读写。
class SystemProxy {
  ///获取代理忽略地址（手机版由 VPN 处理，恒为空）
  static String get proxyPassDomains => '';

  ///获取系统代理（手机版始终为空，直连目标地址）
  static Future<ProxyInfo?> getSystemProxy() async {
    return null;
  }

  ///设置系统代理（手机版由 VPN 接管，空实现）
  static Future<void> setSystemProxy(int port, bool sslSetting, String proxyPassDomains) async {}

  ///设置Https代理启用状态（空实现）
  static void setSslProxyEnable(bool proxyEnable, port) {}

  ///设置系统代理开关（空实现）
  static Future<void> setSystemProxyEnable(int port, bool enable, bool sslSetting,
      {required String passDomains}) async {}

  ///设置代理忽略地址（空实现）
  static Future<void> setProxyPassDomains(String proxyPassDomains) async {}
}
