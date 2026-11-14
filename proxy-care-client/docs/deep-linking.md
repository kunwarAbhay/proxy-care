# Deep linking

The app is web-only for now: there are no `android/` or `ios/` folders yet
(MVP decision 4 is deferred). This document is the integration plan for
when they are added. Nothing below invents a domain: `<APP_LINK_DOMAIN>`
stands for a domain Proxy Care owns and serves over HTTPS, and every value in
angle brackets must be filled in by its owner.

## What the app already does

- go_router receives every incoming link: at a cold start (the platform's
  initial route replaces `RouterOptions.initialLocation`) and while running
  (the platform pushes the new route). No extra code is needed on either
  platform once links are enabled.
- `DeepLinkGuard` accepts a full link only when its scheme is `https` and its
  host is in `RouterOptions.deepLinks.allowedHosts` (empty today); the link
  becomes an in-app location (path and query). Any other link goes to the
  not-found location. Links are then guarded like any navigation: a
  protected link while signed out goes to sign-in with the link kept in
  `from`, and continues after sign-in.
- Identity is in the path, so a linked screen rebuilds fully from the URL.

To enable a domain, set it in the router options (for example, through a
`routerOptionsProvider` override built from configuration):

```dart
const RouterOptions(
  deepLinks: DeepLinkPolicy(allowedHosts: {'<APP_LINK_DOMAIN>'}),
)
```

Only verified `https` links (App Links, Universal Links) are planned. Custom
URL schemes (`proxycare://`) are not used: any app can claim them.

## Android App Links

In `android/app/src/main/AndroidManifest.xml`, inside the main activity:

```xml
<!-- Lets Flutter hand incoming links to the router (default on recent
     Flutter versions; set it explicitly). -->
<meta-data android:name="flutter_deeplinking_enabled" android:value="true" />

<intent-filter android:autoVerify="true">
  <action android:name="android.intent.action.VIEW" />
  <category android:name="android.intent.category.DEFAULT" />
  <category android:name="android.intent.category.BROWSABLE" />
  <data android:scheme="https" android:host="<APP_LINK_DOMAIN>" />
  <!-- Optionally restrict to the paths the app handles: -->
  <!-- <data android:pathPrefix="/<path-prefix>" /> -->
</intent-filter>
```

Domain verification:

1. Serve `https://<APP_LINK_DOMAIN>/.well-known/assetlinks.json` (HTTPS, no
   redirects, `Content-Type: application/json`):

   ```json
   [{
     "relation": ["delegate_permission/common.handle_all_urls"],
     "target": {
       "namespace": "android_app",
       "package_name": "<ANDROID_APPLICATION_ID>",
       "sha256_cert_fingerprints": ["<RELEASE_SIGNING_SHA256>", "<PLAY_APP_SIGNING_SHA256>"]
     }
   }]
   ```

   Include every signing certificate that ships the app (the upload key
   and, with Play App Signing, the key shown in Play Console → App
   integrity).
2. Install a release build and check:
   `adb shell pm get-app-links <ANDROID_APPLICATION_ID>` (state `verified`).
   Re-run verification with
   `adb shell pm verify-app-links --re-verify <ANDROID_APPLICATION_ID>`.
3. Test: `adb shell am start -a android.intent.action.VIEW -d "https://<APP_LINK_DOMAIN>/<path>"`.

## iOS Universal Links

1. Enable **Associated Domains** for the App ID (`<APPLE_TEAM_ID>.<IOS_BUNDLE_ID>`)
   in the Apple Developer portal.
2. In Xcode (Runner → Signing & Capabilities → Associated Domains), add
   `applinks:<APP_LINK_DOMAIN>`. This writes `ios/Runner/Runner.entitlements`:

   ```xml
   <key>com.apple.developer.associated-domains</key>
   <array>
     <string>applinks:<APP_LINK_DOMAIN></string>
   </array>
   ```

   Use one entitlements file per build configuration if staging uses a
   different domain.
3. In `ios/Runner/Info.plist`, let Flutter hand links to the router:

   ```xml
   <key>FlutterDeepLinkingEnabled</key>
   <true/>
   ```
4. Serve `https://<APP_LINK_DOMAIN>/.well-known/apple-app-site-association`
   (no file extension, HTTPS, no redirects, `application/json`):

   ```json
   {
     "applinks": {
       "details": [{
         "appIDs": ["<APPLE_TEAM_ID>.<IOS_BUNDLE_ID>"],
         "components": [{ "/": "/<path-prefix>/*" }]
       }]
     }
   }
   ```

   Apple's CDN caches this file; changes can take time to reach devices.
   During development, `applinks:<APP_LINK_DOMAIN>?mode=developer` bypasses
   the CDN on devices with developer mode on.
5. Test by tapping a link in Notes or Messages (typing it in Safari's
   address bar does not open the app), or with
   `xcrun simctl openurl booted "https://<APP_LINK_DOMAIN>/<path>"`.

## Web

On web the browser URL is the route; no configuration is needed beyond
hosting. The app uses Flutter's default hash URLs (`/#/path`). Switching to
path URLs (`usePathUrlStrategy()`) needs the host to serve `index.html` for
every path; decide this with hosting.

## Checklist when the native targets are added

- [ ] Domain chosen and owned; `<APP_LINK_DOMAIN>` replaced everywhere.
- [ ] `allowedHosts` set per environment.
- [ ] Android intent filter, `assetlinks.json` with all signing
      fingerprints, verification checked on a device.
- [ ] iOS Associated Domains capability, entitlements,
      `FlutterDeepLinkingEnabled`, `apple-app-site-association`, tested on a
      device.
- [ ] A test link for each linked route, signed in and signed out.
