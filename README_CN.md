# ProxyPin

[English](README.md) | 中文
## 开源免费抓包工具 · Android 手机版

您可以使用它来拦截、检查和重写HTTP（S）流量，支持Flutter应用抓包，ProxyPin基于Flutter开发，UI美观易用。

> 本仓库为 **Android 手机版精简分支**：仅保留安卓手机端功能，已移除 Windows / macOS / Linux / iOS 平台工程与桌面端界面。

## 核心特性

* 手机扫码连接: 不用手动配置Wifi代理，包括配置同步。所有终端都可以互相扫码连接转发流量。
* 域名过滤: 只拦截您所需要的流量，不拦截其他流量，避免干扰其他应用。
* 搜索：根据关键词响应类型多种条件搜索请求
* 脚本: 支持编写JavaScript脚本来处理请求或响应。
* 请求重写: 支持重定向，支持替换请求或响应报文，也可以根据增则修改请求或或响应。
* 请求映射: 不请求远程服务，使用本地配置或脚本进行响应
* 请求解密: 配置AES解密密钥，自动解密HTTP消息体
* 请求屏蔽: 支持根据URL屏蔽请求，不让请求发送到服务器。
* 历史记录：自动保存抓包的流量数据，方便回溯查看。支持HAR格式导出与导入。
* MCP 服务: 手机作为 MCP 服务端，供 AI 客户端（Claude Code、Cursor 等）读取抓包、创建重写/脚本等调试规则。
  * 局域网连接：手机绑定 `0.0.0.0` + Bearer 令牌，电脑上的 AI 客户端远程连接。
  * **本地连接（新增）**：手机在 `http://127.0.0.1:9128/mcp` 单独提供无鉴权 MCP 服务，手机内的 AI 客户端（如 Termux 里的 MCP 客户端）可直接连接；电脑也可用 `adb forward tcp:9128 tcp:9128` 转发后以 localhost 访问。设置页内置连接自检，一键验证 `initialize` + `tools/list`。
* 其他：收藏、工具箱、常用编码工具、以及二维码、正则等

## 构建（仅 Android）

```bash
flutter pub get
flutter run -d android        # 或 flutter build apk --release
```

> 桌面依赖（window_manager、desktop_multi_window、screen_retriever、tray_manager、
> win32audio、proxy_manager）已从 `pubspec.yaml` 中移除。

### CI 自动构建（GitHub Actions）

工作流：`.github/workflows/android.yml`

| 触发方式 | 说明 |
| --- | --- |
| 手动 | Actions → Build Android APK → Run workflow，可选 `release/debug` 与 `fat/split/aab` |
| 标签 | 推送 `v*` 标签（如 `git tag v1.3.4 && git push origin v1.3.4`）自动构建并发布 GitHub Release |

`android/app/build.gradle` 的 release 与 debug 均使用 GitHub Actions Secrets 生成的
`android/key.properties` 进行签名。签名为强制要求：任一 Secret 缺失即快速失败，
不再回退临时自签名密钥。请在仓库 **Settings → Secrets and variables → Actions** 配置：

| Secret | 内容 |
| --- | --- |
| `SIGNING_KEY` | keystore 本体，`base64 -w0 release.jks` 的输出（也支持 PKCS12 PEM 文本） |
| `KEY_STORE_PASSWORD` | 密钥库密码 |
| `ALIAS` | 密钥别名 |
| `KEY_PASSWORD` | 密钥密码 |

每次构建成功后产物都会上传到 GitHub Release：推送 `v*` 标签产出正式版，
手动触发则发布到滚动预发布 `ci-latest`（可用 `release_tag` 输入覆盖）。
工作流会在 Gradle 前用 `keytool` 预校验 keystore，密码或别名不对会立即报错，
不再等到打包阶段才失败。

## 赞助 

如果您觉得ProxyPin对您有帮助，欢迎通过以下方式支持我们，帮助项目长期发展：

* [爱发电赞助](https://afdian.com/a/proxypin)
* [Buy Me A Coffee](https://buymeacoffee.com/proxypin)
* 提交反馈和建议，帮助我们改进
* 为项目贡献代码或文档

**您的支持将用于项目的维护、功能开发和用户体验优化，非常感谢！**    

## 下载地址

国内下载： https://gitee.com/wanghongenpin/proxypin/releases

Android Google Play：https://play.google.com/store/apps/details?id=com.network.proxy

TG: https://t.me/proxypin_tg

**接下来会持续完善功能和体验，UI优化。**

<img alt="image"  width="580px" height="420px"  src="https://github.com/user-attachments/assets/80f30d64-f2b5-473c-98f5-bae50b309278">.<img alt="image"  height="500px" src="https://github.com/user-attachments/assets/3c5572b0-a9e5-497c-8b42-f935e836c164">

