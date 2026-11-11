# Tools

| script | purpose |
| --- | --- |
| `extract_from_ipa.py` | decrypt an IPA into `data/` and verify manifest hashes |
| `inventory.py` | print pack counts and encoder coverage (expected: 1548 encoded, 6 gaps) |

Both add the repository root to `sys.path` implicitly when run from the root:

```bash
python tools/extract_from_ipa.py ../com.bimmerlight.prod_v3.9.und3fined.ipa
python tools/inventory.py
```
