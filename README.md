# ProxyPin

English | [中文](README_CN.md)
## Open source free traffic capture HTTP(S) · Android phone edition

You can use it to intercept, inspect & rewrite HTTP(S) traffic, Support capturing Flutter app traffic, ProxyPin is based on Flutter develop, and the UI is beautiful
and easy to use.

> This repository is a **trimmed Android-only fork**: only the phone features are kept. The Windows / macOS / Linux / iOS
> platform projects and the whole desktop UI have been removed.

## Features
* Mobile scan code connection: no need to manually configure WiFi proxy, including configuration synchronization. All terminals can scan codes to connect and forward traffic to each other.
* Domain name filtering: Only intercept the traffic you need, and do not intercept other traffic to avoid interference with other applications.
* Search: Search requests according to keywords, response types and other conditions
* Script: Support writing JavaScript scripts to process requests or responses.
* Request Rewrite: Support redirection, support replacement of request or response message, and can also modify request or response according to the increase.
* Request Mapping: Do not request remote services, use local configuration or scripts for response
* Request Decryption: Configure AES decryption key to automatically decrypt HTTP message body
* Request Blocking: Support blocking requests according to URL, and do not send requests to the server.
* History: Automatically save the captured traffic data for easy backtracking and viewing. Support HAR format export and import.
* MCP service: the phone acts as an MCP server so AI clients (Claude Code, Cursor, ...) can read captures and create rewrite/script rules.
  * LAN connection: the phone binds `0.0.0.0` with a Bearer token for AI clients on other devices.
  * **Local connection (new)**: the phone additionally serves MCP on `http://127.0.0.1:9128/mcp` with no auth, so AI clients running on the
    phone itself (e.g. an MCP client in Termux) can connect directly; a computer can reach it through `adb forward tcp:9128 tcp:9128`.
    The settings page ships a built-in connection self-test (`initialize` + `tools/list`).
* Others: Favorites, toolbox, common encoding tools, as well as QR codes, regular expressions, etc.

## Build (Android only)

```bash
flutter pub get
flutter run -d android        # or: flutter build apk --release
```

## Sponsors

If ProxyPin is helpful to you, you are welcome to support us in the following ways to help the project develop in the long term:

* [Buy Me A Coffee](https://buymeacoffee.com/proxypin)
* [AFDIAN](https://afdian.com/a/proxypin)
* Submit feedback and suggestions to help us improve
* Contribute code or documentation to the project

**Your support will be used for project maintenance, feature development, and user experience optimization. Thank you very much!**

## Downloads

Github Releases: https://github.com/wanghongenpin/proxypin/releases

iOS App Store：https://apps.apple.com/app/proxypin/id6450932949

Android Google Play：https://play.google.com/store/apps/details?id=com.network.proxy

TG: https://t.me/proxypin_en

**We will continue to improve the features and experience, as well as optimize the UI.**

<img alt="image"  width="580px" height="420px"  src="https://github.com/user-attachments/assets/6c1345ab-c95c-415d-ac59-470c764b59a2">.<img alt="image"  height="500px" src="https://github.com/user-attachments/assets/3c5572b0-a9e5-497c-8b42-f935e836c164">


### Powered by
[![JetBrains logo.](https://resources.jetbrains.com/storage/products/company/brand/logos/jetbrains.svg)](https://jb.gg/OpenSource)