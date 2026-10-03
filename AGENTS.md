# AGENTS.md

## What This Project Is
- `proxypin` is an **Android-only** Flutter app with an in-process HTTP(S) proxy core; UI and proxy run in the same app process (`lib/main.dart`, `lib/network/bin/server.dart`).
- Primary value flows are capture -> mutate -> inspect -> persist traffic; the phone UI sits directly on the shared proxy engine.

## Architecture You Need First
- Entry point runs the mobile shell only (`lib/main.dart` -> `MobileHomePage`); there is no desktop/multi-window branch anymore.
- Proxy server lifecycle is owned by `ProxyServer` (start/stop/restart, system proxy toggling, cert init) (`lib/network/bin/server.dart`).
- Socket/channel pipeline lives in `Server`/`Network`; TLS MITM handshake and relay fallbacks happen in `Server.ssl` (`lib/network/channel/network.dart`).
- HTTP request/response routing is centralized in `HttpProxyChannelHandler` and `HttpResponseProxyHandler` (`lib/network/handle/http_proxy_handle.dart`).
- UI pages implement `EventListener` to receive `onRequest/onResponse/onMessage` events from proxy runtime (`lib/ui/mobile/mobile.dart`, `lib/network/bin/listener.dart`).

## Interceptor Model (Core Convention)
- All traffic mutations use `Interceptor` hooks: `preConnect`, `onRequest`, `execute`, `onResponse`, `onError` (`lib/network/components/interceptor.dart`).
- Interceptors are sorted by `priority` before registration; changing order changes behavior (`lib/network/bin/server.dart`).
- Current chain includes hosts, request-map, rewrite, JS script, block, breakpoint, report-server (`lib/network/bin/server.dart`).
- `execute()` can short-circuit remote calls by returning a synthetic `HttpResponse` (used by request mapping) (`lib/network/components/request_map.dart`).

## Persistence + Config Patterns
- Network/runtime config is JSON in app support/home paths (not in repo): `config.cnf`, `request_rewrite.json`, `request_map.json`, `script.json` (`lib/network/bin/configuration.dart`, `lib/network/components/manager/*`).
- UI preferences are separate from proxy config (`ui_config.json`) (`lib/ui/configuration.dart`).
- Captured traffic is persisted as HAR-like records via `HistoryStorage` and periodic `HistoryTask` flushes (`lib/storage/histories.dart`, `lib/utils/har.dart`).
- Favorites intentionally trim websocket/SSE frame count and payload size before persistence (`lib/storage/favorites.dart`).

## Platform Integration Boundaries
- Android native plugins are registered in `MainActivity` (VPN, PiP, lifecycle, installed apps, process info) (`android/app/src/main/kotlin/com/network/proxy/MainActivity.kt`).
- `lib/native/native_method.dart` still keeps the iOS `com.proxypin/method` channel helpers; they are inert on Android (the iOS platform project was removed).
- Pages are pushed through `Navigator` (`lib/ui/component/page_navigator.dart`); the old `desktop_multi_window` plumbing is gone.

## Developer Workflows That Matter
- Install deps: `flutter pub get`.
- Run app: `flutter run -d android` (proxy boot is triggered from UI init, not a separate daemon).
- Run tests: `flutter test` (see protocol-focused tests in `test/websocket_persistence_test.dart`, `test/http_test.dart`, `test/cert_test.dart`).
- Localization is generated from `lib/l10n` using `l10n.yaml`; untranslated keys are tracked in `l10n_errors.txt`.

## Project-Specific Guardrails For Agents
- Do not store runtime defaults in source-only constants if equivalent persisted config exists; update the relevant manager/config serializer too.
- When adding traffic features, prefer a new/interposed `Interceptor` instead of branching deep inside handlers.
- Preserve wildcard URL rule semantics (`*` expansion, escaped `?`) used by rewrite/map rule matchers.
- Keep shared proxy logic in `lib/network/**`; phone-only behavior lives under `lib/ui/mobile/**` and shared widgets under `lib/ui/component/**`.
- Ignore generated/build artifacts (`build/`, platform build outputs) unless the task explicitly targets packaging.

