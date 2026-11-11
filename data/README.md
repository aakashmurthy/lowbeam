# Extracted data

This directory is generated from a BimmerLight 3.9 IPA by
`tools/extract_from_ipa.py`.  The tool decrypts each `*.bimmerlight` file and
verifies its plaintext SHA-256 against the shipped manifest, so the drop can be
reproduced byte-for-byte:

```bash
python tools/extract_from_ipa.py /path/to/com.bimmerlight.prod_v3.9.und3fined.ipa
```

Naming:

| source (`EdiabasKit.framework/`) | destination |
| --- | --- |
| `manifest.bimmerlight` | `manifest.json` |
| `chassis_info.bimmerlight`, `ecu_modules.bimmerlight`, `salapa_info.bimmerlight` | `information/` |
| `<SGBD>.bimmerlight` | `mappings/<SGBD>.json` |
| `<SGBD>.uds.bimmerlight` | `uds/<SGBD>.uds.json` |
| `flash`, `ghost`, `headlight_*`, `one_side`, `party_mode`, `taillight_*`, `toggle` | `packs/` |

The `size` field in the manifest is the size of the base64 file; `sha256` is
the hash of the decrypted JSON.  Both are checked by the extraction tool.
