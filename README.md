# LowBeam — open diagnostic packs and a reference UDS engine

[![Python CI](https://github.com/aakashmurthy/lowbeam/actions/workflows/ci.yml/badge.svg)](https://github.com/aakashmurthy/lowbeam/actions/workflows/ci.yml)
[![iOS build](https://github.com/aakashmurthy/lowbeam/actions/workflows/ios.yml/badge.svg)](https://github.com/aakashmurthy/lowbeam/actions/workflows/ios.yml)

This repository is a clean-room, source-available reconstruction of the data
layer shipped inside the iOS app **BimmerLight 3.9** (bundle
`com.bimmerlight.prod`).  It contains:

* every decrypted `.bimmerlight` pack from the app bundle (ECU action maps,
  UdsEngine job/function tables, chassis and SA codes, light-show scripts);
* the AES-GCM container format and the key that ships in `EdiabasKit`;
* a small, dependency-light Python implementation of the request encoder,
  light-frame builder, Ediabas framing and response decoder described by the
  app's own `CONTRACT.md`;
* documentation of the app's module layout, transports and data flow.

It is **not** the original source code, and it is not affiliated with or
endorsed by BimmerLight or BMW.  See [NOTICE.md](NOTICE.md).

## Quick start

```bash
python -m pip install -r requirements.txt
python -m pytest -q

python -m lowbeam list
python -m lowbeam show FEM_20 LOW_BEAM_LEFT
python -m lowbeam encode FEM_20 LOW_BEAM_LEFT --param param_aktion=1
# 2F 45 01 03 01 01

python -m lowbeam encode FRM3 BRAKE_LEFT --param param_aktion=1
# 2F 01 06 03 64

python -m lowbeam frame "2E D5 42 00 05 00 64" --dest 0x40
# 87 40 F1 2E D5 42 00 05 00 64 66
```

As a library:

```python
from lowbeam import Repo, encode_action, decrypt_pack

repo = Repo()
bundle = repo.bundle("REM_20")
print(encode_action(bundle, "STEUERN_LEUCHTENAUSGANG_DIGITAL", ["SL_L", "1"]).hex())
# 2e45011401
```

## Layout

| Path | Contents |
| --- | --- |
| `data/manifest.json` | pack manifest (sections, remote paths, sizes, sha256) |
| `data/mappings/*.json` | 51 action maps, 1554 actions: `{sgbd,group,description,command,function,args}` |
| `data/uds/*.json` | 52 UdsEngine bundles: `{sgbd,addr,jobs,fns,enums,lights?}` |
| `data/packs/*.json` | 9 light-show scripts (`flash`, `ghost`, `party_mode`, …) |
| `data/information/` | `chassis_info` (5894), `ecu_modules` (439), `salapa_info` (5614) |
| `lowbeam/` | reference implementation (crypto, model, encoder, framing, CLI) |
| `ios/` | LowBeam SwiftUI app: connect screen, light-show runner, script builder (XcodeGen project) |
| `tools/` | helper scripts used during the reconstruction |
| `tests/` | contract examples plus a sweep over all 1554 actions |
| `samples/` | one original encrypted `.bimmerlight` file for crypto tests |

## iOS app

`ios/` contains **LowBeam**, a SwiftUI app that mirrors the original BimmerLight
workflow without a paywall or account:

* **Garage** — connect to a demo vehicle or, experimentally, an ENET/Wi-Fi OBD
  adapter over TCP. The connect screen stages adapter → vehicle → gateway →
  modules and shows the detected VIN, chassis, and module list.
* **Scripts** — play the nine built-in light shows, or open any action to inspect
  its sequence and cleanup steps. The runner resolves each step against the
  detected modules, encodes it, frames it, and sends it; cleanup always runs when
  a show stops or finishes.
* **Build** — compose custom packs from the full 1,554-action database, edit
  steps and parameters, then export an encrypted `.bimmerlight` file.
* **Settings** — adapter defaults, library counts, and onboarding reset.

Bluetooth adapters are shown for reference but this build only implements the
HSFZ/TCP transport. The demo works entirely offline. No server, subscription,
or account is used.

```bash
cd ios
brew install xcodegen
xcodegen generate
open LowBeam.xcodeproj
```

CI builds an unsigned `.ipa` and `.tipa` on every push to `main` and attaches
both to a GitHub release for `v*` tags.  The current build is
[LowBeam v0.1.0](https://github.com/aakashmurthy/lowbeam/releases/tag/v0.1.0);
it is unsigned, so installing it on a device requires re-signing.  See
[ios/README.md](ios/README.md).

## What is verified

* 116/116 shipped `.bimmerlight` files decrypt with the recovered key/layout.
* All five acceptance examples from `CONTRACT.md` reproduce exactly.
* 1548/1554 actions encode; the remaining six are two placeholder entries and
  four FRM3 channels (`BL_L_2`, `BL_R_2`, `ABBL_L`, `ABBL_R`) that are
  referenced by the action map but missing from the shipped light map.
  See `docs/03-uds-engine.md`.
* The Swift encoder in `ios/` reproduces all 1548 Python encodings
  byte-for-byte.
* The unsigned iOS app builds successfully on the macOS CI runner.

## Documentation

* [Data formats](docs/01-data-formats.md)
* [Transport and framing](docs/02-transport.md)
* [UdsEngine rules](docs/03-uds-engine.md)
* [Pack crypto](docs/04-crypto.md)
* [App architecture](docs/05-app-architecture.md)
* [Reverse-engineering notes](docs/06-reverse-engineering.md)

## Safety

The packs describe diagnostic requests only.  Writing arbitrary values to a
car can damage modules; use at your own risk, ideally on a bench setup.

## License

Code: MIT.  Extracted data: CC BY-NC 4.0 (see `NOTICE.md` for the reasoning
and for third-party trademark attribution).
