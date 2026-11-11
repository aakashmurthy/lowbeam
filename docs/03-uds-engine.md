# UdsEngine rules

This is the rule set implemented in `lowbeam/encode.py`; it is derived from
the app's `EdiabasKit.framework/CONTRACT.md` and checked against every shipped
action.  `encode_action(bundle, function, args, params)` returns the **UDS
payload**; wrap it with `ediabas_frame` for the wire.

## 1. Parameter substitution

Any argument of the form `"{name}"` is replaced by `params[name]`.  The
light-show packs are the only callers that use this.

## 2. Pseudo-jobs

These names never appear in `jobs`; the engine handles them directly:

| function | request |
| --- | --- |
| `DIAGNOSE_MODE` | `10 <session>`, session from `DEFAULT=1, ECUPM=2, ECUEXTDIAG=3, ECUSSDS=4, ECUADS=5, SUPPLIER=0x60` |
| `DIAGNOSE_AUFRECHT` | `jobs["DIAGNOSE_AUFRECHT"]` (`3E 01` / `3E FF`) |
| `DIAGNOSE_ENDE` | `lights.fixed["DIAGNOSE_ENDE"]`, else `jobs[...]`, else `10 01` |
| `COMMUNICATION_CONTROL` | `28` + raw args, e.g. `["00","03"]` → `28 00 03` |
| `IO_RETURN_CONTROL` | `2F` + raw args |
| `RAW_UDS` | args are raw hex bytes |

## 3. Light frames

If `bundle.lights.function == function` the request is a light frame, not a
normal job:

```
frame = bytearray(template)
for (offset, mask) in channels[channel]: frame[offset] |= mask
for (offset, mask) in state.on if on else state.off: frame[offset] |= mask
```

* `on` is the second argument (`"1"`, `"ein"`, `"true"`, …); absent means on.
* No arguments at all means **all off** and yields the bare template
  (the `ALL_OFF` actions).
* Examples:
  * `FRM3 STEUERN_DIGITAL_LICHT ["AL_L","1"]` →
    `2F 01 04 03 64`
  * `REM_20 STEUERN_LEUCHTENAUSGANG_DIGITAL ["SL_L","1"]` →
    `2E 45 01 14 01`
  * `LCM STATUS_VORGEBEN ["AL_L"]` →
    `D0 10 0C 00 00 00 00 40 00 00 00 00 00 00 00`

## 4. Job base

`base = jobs[function]`.  A base may contain the service, identifier and
fixed control bytes, e.g. `STEUERN_LEUCHTENAUSGANG_DIGITAL = 2F 45 01 03 00 00`.

Values are encoded big-endian.  If the base ends in as many zero bytes as the
encoded argument body, those bytes are **overwritten** (not appended):

```
base 2F 45 01 03 00 00 + ["0x01","1"] → 2F 45 01 03 01 01
```

Otherwise the body is appended:

```
KOMB_G11 STEUERN_CC_MELDUNG_TRIGGERN base 31 01 F0 12
  + ["0x01","0xfc","0x32","0x21"] → 31 01 F0 12 01 FC 32 21
```

## 5. `ARG` dispatch

`args = ["ARG", target, ...]` selects `fns[target]` whose service byte matches
`base[0]`.  The remaining values fill `fn.a`.

### Service 0x2E (write data by identifier)

```
2E <fn.id> <args...>
```

### Service 0x2F (input/output control)

The first remaining value is the control parameter:

| symbol | byte |
| --- | --- |
| `RCTECU` / `returnControlToECU` | 0x00 |
| `RTD` / `resetToDefault` | 0x01 |
| `FCS` / `freezeCurrentState` | 0x02 |
| `STA` / `shortTermAdjustment` | 0x03 |

```
2F <fn.id> <control> <args...>
```

If no further values are supplied (`RESET_TO_ECU`) the request stops after the
control byte.

### Service 0x31 (routine control)

The first remaining value is the routine sub-function:

| symbol | byte |
| --- | --- |
| `STR` / start | 0x01 |
| `STPR` / stop | 0x02 |
| `RRR` / request results | 0x03 |

```
31 <sub> <fn.id> <args...>
```

A stop request without arguments (`STOP_ROUTINE`) stops after the id.

### Same-name overloads

`find_fn(name, service)` prefers the entry whose `s` equals the base service;
this disambiguates pairs such as `REFERENZLAUFZAEHLER_LWR` at service 0x2E and
0x22.

## 6. Named arguments (LHM2)

`_LEUCHTEN_AUSSENLICHT_KANAELE` has 14 one-byte fields (7 brightness, 7
current).  The action supplies `("KANAL3_HELLIGKEIT", value)`; the encoder
builds a 14-byte body of zeros with that field set:

```
base 2E 60 60, KANAL3_HELLIGKEIT=100
→ 2E 60 60 00 00 64 00 00 00 00 00 00 00 00 00 00 00
```

## 7. Scaling

`{"s":[mul,div,add]}` documents how a **response** value is displayed:
`display = raw * mul / div + add`.  The argument values shipped in the packs
are already in raw ECU units, so they are encoded unchanged.  (This is why
`param_lhm2_pwm=250` becomes `0xFA`, and `ZEIT=100` stays `0x64`.)

## 8. Response decoding

`parse_response(bundle, function, data)`:

1. built-in parsers for `IDENT`, VIN (`22 F1 90`), `C_FG_LESEN` and the six
   FA fields (`22 3F 06` / `22 3F 00`);
2. otherwise the `fn.r` specs, reading big-endian by default, honouring
   `o:"L"`, `m`, `s`, `e` and `bf` when present.

## 9. Known gaps

Six of the 1554 actions cannot be encoded from the shipped data:

* `FRM3 XX` and `REM_20 INV` — explicit placeholders with empty `command`;
* `FRM3 BRAKE_LEFT_2` (`BL_L_2`), `BRAKE_RIGHT_2` (`BL_R_2`),
  `CORNERING_LEFT` (`ABBL_L`), `CORNERING_RIGHT` (`ABBL_R`) — channels used
  by the action map but absent from `FRM3.uds`'s `lights.channels`.  The app
  either aliases them at runtime or also fails to send them; no alias is
  supported here to avoid sending a wrong lamp.

## 10. Coverage

`tests/test_packs.py::test_every_mapping_action_encodes` sweeps all 1554
actions and asserts that only the six gaps above fail.
