"""Rebuild ``data/`` from a BimmerLight ``.ipa``.

Usage:
    python tools/extract_from_ipa.py com.bimmerlight.prod_v3.9.und3fined.ipa

The tool reads the ``.bimmerlight`` files straight out of the zip, decrypts
them with the bundle key (see ``docs/04-crypto.md``), verifies the plaintext
SHA-256 against the manifest and writes the same layout as the repository.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from lowbeam import decrypt_pack

FRAMEWORK = "Payload/BimmerLight.app/Frameworks/EdiabasKit.framework/"
INFO = {"chassis_info", "ecu_modules", "salapa_info"}
SHOWS = {
    "flash",
    "ghost",
    "headlight_flash",
    "headlight_show",
    "one_side",
    "party_mode",
    "taillight_flash",
    "taillight_show",
    "toggle",
}


def classify(stem: str) -> Path:
    if stem == "manifest":
        return Path("manifest.json")
    if stem in SHOWS:
        return Path("packs") / f"{stem}.json"
    if stem.endswith(".uds"):
        return Path("uds") / f"{stem}.json"
    if stem in INFO:
        return Path("information") / f"{stem}.json"
    return Path("mappings") / f"{stem}.json"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("ipa")
    parser.add_argument("--out", default="data")
    parser.add_argument("--no-verify", action="store_true")
    args = parser.parse_args()

    out = Path(args.out)
    written = 0
    with zipfile.ZipFile(args.ipa) as archive:
        names = [n for n in archive.namelist() if n.startswith(FRAMEWORK) and n.endswith(".bimmerlight")]
        if not names:
            raise SystemExit("no EdiabasKit .bimmerlight files in this IPA")

        docs = {}
        for name in names:
            stem = Path(name).name[: -len(".bimmerlight")]
            target = classify(stem)
            plain = decrypt_pack(archive.read(name))
            docs[target] = plain

        manifest = json.loads(docs[Path("manifest.json")])
        if not args.no_verify:
            expected = {
                Path(entry["path"]).name.replace(".bimmerlight", ".json"): entry["sha256"]
                for section in manifest["sections"].values()
                for entry in section["files"]
            }
            for target, plain in docs.items():
                if target.name == "manifest.json":
                    continue
                want = expected.get(target.name)
                if want and hashlib.sha256(plain).hexdigest() != want:
                    raise SystemExit(f"sha256 mismatch for {target}")

        for target, plain in sorted(docs.items()):
            path = out / target
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(plain)
            written += 1

    print(f"wrote {written} files to {out}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
