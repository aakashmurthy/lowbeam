"""Command line interface for the LowBeam toolkit."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .crypto import decrypt_pack, encrypt_pack
from .repo import Repo
from .uds import ediabas_frame, parse_response


def _params(pairs):
    out = {}
    for pair in pairs or []:
        if "=" not in pair:
            raise SystemExit(f"--param expects key=value, got {pair!r}")
        key, value = pair.split("=", 1)
        out[key] = value
    return out


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="lowbeam", description=__doc__)
    parser.add_argument("--root", default=None, help="repository root (default: auto)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("manifest", help="print the pack manifest")
    p = sub.add_parser("list", help="list action packs")
    p.add_argument("--sgbd", default=None)

    p = sub.add_parser("show", help="show one action")
    p.add_argument("sgbd")
    p.add_argument("command")

    p = sub.add_parser("encode", help="encode an action from the action maps")
    p.add_argument("sgbd")
    p.add_argument("command")
    p.add_argument("--param", action="append", metavar="K=V")

    p = sub.add_parser("encode-fn", help="encode a raw function call")
    p.add_argument("sgbd")
    p.add_argument("function")
    p.add_argument("--arg", action="append", default=[])
    p.add_argument("--param", action="append", metavar="K=V")

    p = sub.add_parser("decrypt", help="decrypt a .bimmerlight file")
    p.add_argument("file")
    p = sub.add_parser("encrypt", help="encrypt JSON into a .bimmerlight file")
    p.add_argument("file")
    p.add_argument("--out", default=None)

    p = sub.add_parser("frame", help="wrap a hex payload in an Ediabas frame")
    p.add_argument("hex")
    p.add_argument("--dest", default="0x40")

    p = sub.add_parser("parse", help="decode a hex response using a function spec")
    p.add_argument("sgbd")
    p.add_argument("function")
    p.add_argument("hex")

    args = parser.parse_args(argv)
    repo = Repo(args.root)

    if args.cmd == "manifest":
        print(json.dumps(repo.manifest, indent=2, ensure_ascii=False))
    elif args.cmd == "list":
        for sgbd, actions in repo.mappings.items():
            if args.sgbd and sgbd.upper() != args.sgbd.upper():
                continue
            print(f"{sgbd}: {len(actions)} actions")
    elif args.cmd == "show":
        print(json.dumps(repo.action(args.sgbd, args.command), indent=2, ensure_ascii=False))
    elif args.cmd == "encode":
        action = repo.action(args.sgbd, args.command)
        payload = repo.encode(
            args.sgbd, action["function"], action["args"], _params(args.param)
        )
        print(payload.hex(" ").upper())
    elif args.cmd == "encode-fn":
        payload = repo.encode(args.sgbd, args.function, args.arg, _params(args.param))
        print(payload.hex(" ").upper())
    elif args.cmd == "decrypt":
        print(decrypt_pack(Path(args.file).read_bytes()).decode("utf-8"))
    elif args.cmd == "encrypt":
        sealed = encrypt_pack(Path(args.file).read_bytes())
        if args.out:
            Path(args.out).write_bytes(sealed)
            print(args.out)
        else:
            print(sealed.decode())
    elif args.cmd == "frame":
        payload = bytes.fromhex(args.hex.replace(" ", ""))
        print(ediabas_frame(payload, int(args.dest, 0)).hex(" ").upper())
    elif args.cmd == "parse":
        data = bytes.fromhex(args.hex.replace(" ", ""))
        print(
            json.dumps(
                parse_response(repo.bundle(args.sgbd), args.function, data),
                indent=2,
                ensure_ascii=False,
            )
        )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
