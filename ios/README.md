# LowBeam for iOS

A SwiftUI companion that mirrors the BimmerLight workflow without a paywall or
account. It reads the JSON packs from `../data` (embedded as a folder reference).

## Screens

* **Garage** — a connect screen with demo and ENET/Wi-Fi options. Connecting
  stages adapter → vehicle → gateway → modules and shows the detected VIN,
  chassis, and module list. Demo mode uses a simulated F30 and needs no hardware.
* **Scripts** — the nine built-in light shows plus your own scripts. Open a pack
  to browse actions, inspect every sequence and cleanup step, and run a show.
  The runner resolves each step against the connected modules, encodes the UDS
  payload, frames it, and sends it over the selected transport. Cleanup steps
  always run when a show stops or finishes.
* **Build** — create a pack, add actions, pick steps from the full 1,554-action
  database, set groups/parameters/delays, and choose icons and colors. Packs are
  stored in Application Support and can be exported as encrypted
  `.bimmerlight` files (AES-256-GCM, same container as the original app).
* **Settings** — adapter defaults (`192.168.0.10:6801`), library counts, delete
  custom scripts, and reset onboarding.

The first launch shows a welcome screen with **Connect vehicle** and **Browse
offline** actions.

## Transport

The only live transport is **HSFZ over TCP**, used by ENET cables and several
Wi-Fi adapters. It sends `[length][00 01][source][dest][Ediabas frame]` and
parses the same header on responses. This path is experimental; verify it on a
bench or parked car before relying on it.

Bluetooth adapters (OBDLink, KONNWEI, vLinker, Vgate, Veepeak) are listed in the
connect screen for parity with the original app, but this build does not
implement Bluetooth yet.

No server, subscription, account, analytics, or ads are used.

## Requirements

* Xcode 16 or newer
* [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## Build

```bash
xcodegen generate
open LowBeam.xcodeproj
```

Or from the command line, unsigned:

```bash
xcodebuild \
  -project LowBeam.xcodeproj \
  -scheme LowBeam \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build
```

The app is generated at
`build/Build/Products/Release-iphoneos/LowBeam.app`.

## Unsigned IPA / TIPA

The `iOS` GitHub Actions workflow builds the same configuration and packages the
app as both `LowBeam.ipa` and `LowBeam.tipa` on every push to `main`, every pull
request, and every `v*` tag. Tag builds are attached to the GitHub release.

The packages are unsigned. They are useful for inspection, for TrollStore, or
as a starting point for your own signing; they are not App Store builds.

## Limitations

* Bluetooth, CarPlay, and the original app's music-reactive mode are not
  implemented.
* The ENET transport is a best-effort reconstruction from the shipped
  `HSFZNetworkService`; the TCP port and adapter behavior may vary.
* The six known encoding gaps (two placeholder rows and four FRM3 channels)
  surface as an error in the inspector.
* The Xcode project is generated; do not edit `LowBeam.xcodeproj` by hand.
