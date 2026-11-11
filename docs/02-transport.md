# Transport and framing

## Ediabas frame (K-line / DS2 / external accessory)

`CONTRACT.md` and the decompiled `UDSPacketAssembler` agree on this layout:

```
+--------+--------+--------+-------------------+----------+
| 0x80|n |  dest  | source |  payload (n bytes)| checksum |
+--------+--------+--------+-------------------+----------+
```

* `n` is the payload length (0…0x3F for a single frame).
* `dest` is the ECU diagnostic address (`addr` in the UdsEngine bundle,
  e.g. `"72"` → 0x48).
* `source` is 0xF1 (tester).
* `checksum` is the **wrapping byte sum** of all preceding bytes, not a XOR.
  `CONTRACT.md` writes it as Swift `reduce(0, &+)`, which is addition.

Worked example from the contract:

```
payload 2E D5 42 00 05 00 64, dest 0x40
frame   87 40 F1 2E D5 42 00 05 00 64
sum     0x87+0x40+0xF1+0x2E+0xD5+0x42+0x00+0x05+0x00+0x64 = 0x366 → 0x66
```

Python:

```python
from lowbeam import ediabas_frame
ediabas_frame(bytes.fromhex("2ED54200050064"), 0x40).hex()
# '8740f12ed5420005006466'
```

## ISO-TP (Bluetooth adapters)

`IsoTpBluetoothServiceBase.swift` and `BluetoothServiceBase.swift` wrap the
same payload in ISO-TP:

| frame | first byte | meaning |
| --- | --- | --- |
| single | `0x0n` | n payload bytes follow |
| first | `0x1nnn` | 12-bit total length, 6 payload bytes follow |
| consecutive | `0x2n` | n payload bytes |
| flow control | `0x30…` | CTS / wait / overflow |

Only single frames are produced by the shipped packs (all requests are short).
The Bluetooth layer also handles adapter-specific AT commands
(`ObdlinkBluetooth`, `VgateIcarBluetooth`, `VeepeakBluetooth`,
`UniCarScanBluetooth`, `KonnweiBluetooth`, `VlinkerBluetooth`,
`BimmerCommanderBluetooth`).

## Network transports

| service | protocol | notes |
| --- | --- | --- |
| `HSFZNetworkService` | BMW HSFZ over TCP | ENET/DoIP-like, used by F/G-series |
| `ThorNetworkService` | THOR over Wi-Fi | newer head units |
| `VlinkerNetworkService` | Wi-Fi socket | vLinker adapters |
| `Bm3Network`, `MhdNetwork`, `ModBmNetwork`, `WifiNetwork` | vendor Wi-Fi | bootmod3 / MHD / xHP style |

`DetectVehicleService` probes these endpoints before a connection is offered.

## Positive response headers

`parse_response` skips the service-specific prefix before reading result
fields:

| response SID | bytes to skip | example |
| --- | --- | --- |
| `0x62` (read data by id) | 3 | `62 F1 90 <17 ASCII>` |
| `0x5A` (read VIN, KWP) | 2 | `5A 90 <17 ASCII>` |
| `0x61` (routine result) | 2 | `61 <routine id>` |
| `0x71` (routine result, UDS) | 4 | `71 01 <id> <status>` |
| `0xA0` | 3 | vendor-specific |

Negative responses are `0x7F <sid> <nrc>` and are not decoded by the engine.
