"""Read-only access to the open data drop in ``data/``."""

from __future__ import annotations

import json
from pathlib import Path

from .encode import encode_action
from .model import Bundle


class Repo:
    """Loads the decrypted packs shipped in this repository."""

    def __init__(self, root: str | Path | None = None) -> None:
        self.root = Path(root) if root else Path(__file__).resolve().parent.parent
        self.data = self.root / "data"
        self._bundles: dict[str, Bundle] | None = None
        self._bundles_ci: dict[str, Bundle] = {}
        self._mappings: dict[str, list[dict]] | None = None
        self._packs: dict[str, dict] | None = None
        self.manifest = self._read(self.data / "manifest.json")

    @staticmethod
    def _read(path: Path):
        return json.loads(path.read_text(encoding="utf-8"))

    @property
    def bundles(self) -> dict[str, Bundle]:
        if self._bundles is None:
            self._bundles = {
                p.name[: -len(".uds.json")]: Bundle.from_json(self._read(p))
                for p in sorted((self.data / "uds").glob("*.uds.json"))
            }
            self._bundles_ci = {k.upper(): v for k, v in self._bundles.items()}
        return self._bundles

    @property
    def mappings(self) -> dict[str, list[dict]]:
        if self._mappings is None:
            self._mappings = {
                p.stem: self._read(p)
                for p in sorted((self.data / "mappings").glob("*.json"))
            }
        return self._mappings

    @property
    def packs(self) -> dict[str, dict]:
        if self._packs is None:
            self._packs = {
                p.stem: self._read(p)
                for p in sorted((self.data / "packs").glob("*.json"))
            }
        return self._packs

    @property
    def chassis(self) -> list[dict]:
        return self._read(self.data / "information" / "chassis_info.json")

    @property
    def ecu_modules(self) -> list[dict]:
        return self._read(self.data / "information" / "ecu_modules.json")

    @property
    def salapa(self) -> list[dict]:
        return self._read(self.data / "information" / "salapa_info.json")

    def bundle(self, sgbd: str) -> Bundle:
        _ = self.bundles  # ensure the index is built
        try:
            return self._bundles_ci[sgbd.upper()]
        except KeyError as exc:
            raise KeyError(f"unknown SGBD {sgbd!r}") from exc

    def action(self, sgbd: str, command: str) -> dict:
        entries = self.mappings.get(sgbd)
        if entries is None:
            entries = next(
                (v for k, v in self.mappings.items() if k.upper() == sgbd.upper()),
                None,
            )
        if entries is None:
            raise KeyError(f"unknown SGBD {sgbd!r}")
        for entry in entries:
            if entry.get("command") == command:
                return entry
        raise KeyError(f"{sgbd} has no action {command!r}")

    def encode(self, sgbd: str, function: str, args=(), params=None) -> bytes:
        bundle = self.bundles.get(sgbd) or self._bundles_ci.get(sgbd.upper())
        if bundle is None:
            # A few SGBDs (e.g. KOMB_SP21) only use pseudo jobs that need no
            # per-ECU job table; encoding still works with an empty bundle.
            bundle = Bundle(sgbd=sgbd, addr="", jobs={}, fns=(), enums={})
        return encode_action(bundle, function, args, params)
