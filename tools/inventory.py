"""Print pack counts and encoder coverage."""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lowbeam import Repo, encode_action

PARAMS = {
    "param_steuern_io": "STA",
    "param_steuern_routine": "STR",
    "param_aktion": "1",
    "param_aktion_einaus": "ein",
    "param_zeit": "100",
    "param_lhm_zeit": "100",
    "param_lhm_pwm": "100",
    "param_lhm2_pwm": "250",
    "param_rlm_strom_ausgang_wert": "100",
}


def main() -> int:
    repo = Repo()
    actions = sum(len(v) for v in repo.mappings.values())
    encoded = failed = 0
    failures = []
    for sgbd, entries in repo.mappings.items():
        bundle = repo.bundles.get(sgbd) or repo._bundles_ci.get(sgbd.upper())
        for entry in entries:
            try:
                if bundle is None:
                    repo.encode(sgbd, entry["function"], entry["args"], PARAMS)
                else:
                    encode_action(bundle, entry["function"], entry["args"], PARAMS)
                encoded += 1
            except Exception as exc:  # noqa: BLE001
                failed += 1
                failures.append(f"{sgbd}/{entry['command']}: {exc}")

    print(f"mappings       {len(repo.mappings)}")
    print(f"actions        {actions}")
    print(f"uds bundles    {len(repo.bundles)}")
    print(f"light shows    {len(repo.packs)}")
    print(f"chassis        {len(repo.chassis)}")
    print(f"ecu modules    {len(repo.ecu_modules)}")
    print(f"sa codes       {len(repo.salapa)}")
    print(f"encoded        {encoded}")
    print(f"failed         {failed}")
    for line in failures:
        print("  ", line)
    return 0 if encoded == actions - 6 else 1


if __name__ == "__main__":
    raise SystemExit(main())
