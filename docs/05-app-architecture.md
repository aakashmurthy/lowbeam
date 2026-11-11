# App architecture (as recovered)

The app is a SwiftUI iOS application split into three binaries plus vendor SDKs:

| binary | role |
| --- | --- |
| `BimmerLight` | UI, screens, app services, subscriptions |
| `BimmerLightKit` | subscription store, entitlements, shared models |
| `EdiabasKit` | diagnostics: transport, packs, UDS engine, light executor |

All three are thin arm64 Mach-O, built with Xcode 26.1 / iOS SDK 26.1,
minimum iOS 17.6.  Debug paths leaked by the binary give the original tree:

```
/Users/metlnt/Developer/bimmerlight/
  ios/app/…
  ios/BimmerLightKit/…
  ios/EdiabasKit/…
```

## UI layer (`ios/app`)

| screen | view model |
| --- | --- |
| Connection | `ConnectionScreen/*ViewModel.swift` |
| Welcome | `WelcomeScreen` |
| Action packs | `ActionPackScreen`, `PackListScreen` |
| Pack editor | `EditActionPackScreen` |
| Module tests | `ModuleTestsScreen` |
| Settings | `SettingsScreen` |
| Subscription | `SubscriptionScreen` |
| Support | `SupportScreen` |
| Web / legal | `WebScreen` |

`SceneDelegate.swift` hosts the SwiftUI window; `CarPlaySceneDelegate` mirrors
the light-show controls to CarPlay.  `AppDelegate` wires notifications,
crash reporting (Firebase/Crashlytics), Amplitude analytics and Facebook SDK.

App-level services:

* `AutoConnectService` — remembers the last adapter/vehicle and reconnects.
* `NotificationManager` — local notifications for long-running jobs.
* `SupportRequestSender` — posts diagnostics bundles to the support endpoint.
* `CrashReporting` — Crashlytics wrapper.

## Diagnostics layer (`ios/EdiabasKit`)

### Transport

```
NetworkServiceBase
├── BluetoothServiceBase
│   └── IsoTpBluetoothServiceBase
│       ├── ObdlinkBluetoothService / ObdlinkMxBluetooth
│       ├── VgateIcarBluetoothService
│       ├── VeepeakBluetoothService
│       ├── VlinkerBluetoothService
│       ├── UniCarScanBluetoothService
│       ├── KonnweiBluetoothService
│       └── BimmerCommanderBluetoothService
├── HSFZNetworkService (DetectVehicleService)
├── ThorNetworkService
├── VlinkerNetworkService
├── WifiNetworkService
└── vendor networks: Bm3Network, MhdNetwork, ModBmNetwork
```

`OBDLinkEAService` is the ExternalAccessory implementation for OBDLink MX+
(`com.obdlink` protocol, `external-accessory` background mode).  Bluetooth
adapters use `bluetooth-central`.

`UDSPacketAssembler` builds the Ediabas frame and the ISO-TP layer.

### Data stores

| store | file |
| --- | --- |
| `JSONDatastore` | base JSON loader (bundle + documents) |
| `JSONManifestDatastore` / `ManifestDatastore` | `manifest.bimmerlight` |
| `JSONActionPackDatastore` / `ActionPackDatastore` | `*.bimmerlight` action maps |
| `JSONMappingDatastore` | SGBD → action map index |
| `UdsBundleStore` | `*.uds.bimmerlight` |
| `DiskVehicleStore` | saved vehicles |
| `ModuleTestRunStore` | module-test history |
| `SubscriptionStore` (`BimmerLightKit`) | StoreKit 2 entitlements |

`RawActionPack`, `RawManifest`, `ActionPack`, `Manifest`, `BundleToken`,
`UdsBundleToken` are the decoded model types.  `Crypto.swift` holds the key and
the AES-GCM helpers described in `04-crypto.md`.

### Services and use cases

* `EdiabasService` — session orchestration: connect, detect, read VIN/FA, run
  jobs, disconnect.
* `ExecuteLightService` + `ExecuteLightQueue` — serialises light-show steps so
  frames from different ECUs do not interleave.
* `DetectVehicleModule` — maps VIN/FA and `chassis_info` to candidate SGBDs.
* `CheckForUpdates` — fetches the manifest and syncs changed sections.
* `EditActionPack` / `ReadActionPack` — user-defined commands; `KeyStep`,
  `BehaviourKey`, `flashable` describe sequential key/behaviour editing.
* `ActiveVehicleHolder` — current vehicle and connection state.
* `HTTPClient` — `requestEncrypted` download with plaintext SHA-256 check.

### Runtime flow

```
launch
  └─ load manifest + information tables (encrypted, shipped)
connect(adapter)
  └─ DetectVehicleService → transport up
  └─ read VIN (22 F1 90) and FA (22 3F 06)
  └─ resolve chassis → candidate SGBDs via ecu_modules
select action / light show
  └─ action map entry → encode_action → Ediabas frame → transport
  └─ response → parse_response → status/values
```

Light shows run as sequences of `command` values.  For every SGBD in the
step's `group` the executor looks up the same `command`; missing commands are
skipped, which is how one script covers many chassis.

## Networking

| endpoint | use |
| --- | --- |
| `https://api.bimmerlight.com/` | account, subscriptions, support, updates |
| `https://cdn.bimmerlight.com/2026-09-25/…` | encrypted pack downloads |
| S3 bucket `bimmerlight-apps.prod` | backing storage for the CDN |
| Amplitude / Firebase / Facebook | analytics, crashes, login |

The manifest is the update index; each section carries `path`, base64 `size`
and plaintext `sha256`.  Downloads are decrypted with the same key as the
shipped packs and verified before being written to disk.
