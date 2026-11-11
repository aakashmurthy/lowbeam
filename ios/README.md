# LowBeam for iOS

An offline pack browser and request encoder.  It reads the JSON packs from
`../data` (embedded as a folder reference) and shows, for every action:

* the function, group, and argument list from the action map;
* the encoded UDS payload;
* the framed Ediabas request (`[0x80|len, dest, source] + payload + checksum`).

The on/off toggle covers actions that take `param_aktion` or
`param_aktion_einaus`; the other parameter defaults match the shipped light-show
scripts (`STA`, `STR`, Zeit/PWM values).

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
request, and every `v*` tag.  Tag builds are attached to the GitHub release.

The packages are unsigned.  They are useful for inspection, for TrollStore, or
as a starting point for your own signing; they are not App Store builds.

## Limitations

* No Bluetooth, OBD, CarPlay, or network transport yet — the app only encodes.
* No editor for action maps or packs; edit the JSON under `data/` and rebuild.
* The six known encoding gaps (two placeholder rows and four FRM3 channels)
  surface as an error in the detail view.
* The Xcode project is generated; do not edit `LowBeam.xcodeproj` by hand.
