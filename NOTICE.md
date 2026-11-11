# NOTICE

## Affiliation

This project is an independent interoperability and research effort.  It is not
affiliated with, authorized by, sponsored by, or endorsed by BimmerLight, BMW
AG, or any of their subsidiaries.  "BMW", "BimmerLight", "Ediabas", "INPA" and
other names are trademarks of their respective owners and are used only to
describe compatibility.

## Where the data came from

The JSON files under `data/` were extracted from a legally obtained copy of the
iOS application **BimmerLight 3.9** (`com.bimmerlight.prod`, build 56).  They
were stored in the app bundle as base64-encoded AES-GCM containers and were
decrypted with the key that ships in the same bundle.  No server was accessed,
no account was used, and no paywalled content was downloaded; everything here
was already present on the device.

The extracted documents describe diagnostic requests (UDS/KWP services, DIDs,
routine identifiers, lamp bit maps) for BMW ECUs.  They contain no personal
data, credentials, VINs, or customer records.

## Licensing

* Source code (`lowbeam/`, `tests/`, `tools/`): MIT, see `LICENSE`.
* Extracted data (`data/`, `samples/`): CC BY-NC 4.0.  You may share and adapt
  it for non-commercial purposes with attribution.  Commercial use requires a
  separate arrangement with the rights holders.

If you are a rights holder and believe an item should not be distributed here,
open an issue and it will be removed promptly.

## Safety and legality

Diagnostic requests can change ECU configuration and, in the wrong context,
damage a vehicle.  Nothing here is a substitute for the manufacturer's service
information.  You are responsible for complying with local law, warranty
terms, and emissions regulations when using this material.  Prefer a bench
setup; never run experimental writes on a vehicle you depend on.
