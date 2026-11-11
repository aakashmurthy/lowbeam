# Data formats

All documents were shipped base64-encoded and AES-GCM sealed (see
`04-crypto.md`).  Once decrypted they are UTF-8 JSON without a BOM.

## Manifest (`data/manifest.json`)

```json
{
  "generated_at": "2026-09-25T08:35:37Z",
  "cdn_base": "https://cdn.bimmerlight.com",
  "sections": {
    "information": {"version": ..., "count": 3, "hash": ..., "files": [...]},
    "mappings":    {"count": 51, "files": [...]},
    "packs":       {"count": 9,  "files": [...]},
    "uds":         {"count": 52, "files": [...]}
  }
}
```

Each file entry is `{path, size, sha256}`.  `path` is relative to `cdn_base`
and starts with a dated directory (`2026-09-25/...`).  The shipped copies are
smaller than the remote `size` values, so the manifest cannot be used to
verify the on-device files; treat it as an update index.

## Action maps (`data/mappings/<SGBD>.json`)

A flat array.  Every entry is one user-visible command:

```json
{
  "sgbd": "FRM3",
  "group": "FRM",
  "description": "2. Bremslicht links",
  "command": "BRAKE_LEFT_2",
  "function": "STEUERN_DIGITAL_LICHT",
  "args": ["BL_L_2", "{param_aktion}"]
}
```

* `command` is the stable identifier used by light-show scripts.  Two entries
  have an empty command and are placeholders ("unknown light", "INV").
* `function` names a job in the matching UdsEngine bundle, one of the
  pseudo-jobs (`DIAGNOSE_*`, `RAW_UDS`, `COMMUNICATION_CONTROL`,
  `IO_RETURN_CONTROL`), or a light-map function.
* `args` are ordered values.  `"{param_x}"` is substituted from the caller
  (the light-show packs supply these).  `"ARG"` in position 0 switches to
  function dispatch, see `03-uds-engine.md`.

## UdsEngine bundles (`data/uds/<SGBD>.json`)

```json
{
  "sgbd": "REM_20",
  "addr": "72",
  "jobs": {"STEUERN": "2e", "STEUERN_IO": "2f", "...": "..."},
  "fns": [{"n": "LEUCHTEN_FUNKTION", "s": 46, "id": "D542",
           "a": [["ELEMENT", 2, "TAB_LEUCHTEN_FUNKTION_ARG"],
                 ["ZEIT", 2, {"s": [100, 1, 0]}]],
           "r": [["STAT_UNBELEGT_0", 1], "..."]}],
  "enums": {"TAB_LEUCHTEN_FUNKTION_ARG": {"AL_L": 1, "...": 0}},
  "lights": {
    "function": "STEUERN_LEUCHTENAUSGANG_DIGITAL",
    "template": "2E 45 01 00 00",
    "channels": {"SL_L": [[3, "0x14"]], "SL_R": [[3, "0x15"]]},
    "state": {"on": [[4, "0x01"]], "off": []},
    "fixed": {"DIAGNOSE_ENDE": "D0 04 9F"}
  }
}
```

`addr` is the diagnostic address as a decimal string (e.g. `"72"` = 0x48).
It is used for the destination byte of the Ediabas frame.

Every `fns` entry:

| field | meaning |
| --- | --- |
| `n` | function name |
| `s` | UDS service byte used on the wire |
| `id` | optional hex identifier (DID / routine id) |
| `a` | argument specs |
| `r` | result specs |
| `p` | `vm` (default) or `raw` |

Argument spec: `[name, width]`, `[name, width, enumTable]` or
`[name, width, {"e": enumTable, "s": [mul, div, add]}]`.
Widths: byte/char = 1, word/short/int = 2, dword/long = 4, double = 8,
`data[N]`/`string[N]` = N.

Result spec (all 29,354 shipped entries are the simple form): `[name, width]`
or `{"o": "L", "m": mask, "s": [mul, div, add], "e": enumTable,
"bf": [[name, mask], ...]}`.

## Light-show packs (`data/packs/*.json`)

```json
{
  "title": "Flash",
  "description": "...",
  "sgbds": ["...51 SGBD names..."],
  "icon": "...",
  "group": "...",
  "index": 0,
  "column_count": 3,
  "file_name": "flash",
  "actions": [
    {"title": "Flash", "icon": "...", "color": "...", "align": "center",
     "sequence": [
       {"command": "LOW_BEAM_LEFT", "group": ["FRM3", "..."],
        "params": {"param_aktion": "1"}}
     ]}
  ]
}
```

A sequence step targets every SGBD in `group` that has a matching `command`
in its action map.  This is why the same script works across chassis.

## Information tables

* `chassis_info.json` — 5894 rows `{name, chassis, region, engine, body,
  steering, series}` used to identify a car from its VIN/FA.
* `ecu_modules.json` — 439 rows `{ADR_INDEX, SGBD_HEX, SGBD, GRUPPE,
  BAUREIHE}`: the address book used to route frames.
* `salapa_info.json` — 5614 option codes `{code, title}`.
