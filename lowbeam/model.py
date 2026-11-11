"""Typed view of the decrypted JSON documents (``*.bimmerlight``)."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Iterable


def _hex_bytes(value: str | None) -> bytes | None:
    if value is None:
        return None
    value = value.strip()
    if value.startswith("0x"):
        value = value[2:]
    value = value.replace(" ", "")
    if len(value) % 2:
        value = "0" + value
    return bytes.fromhex(value)


def _int(value: Any) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        return int(value, 0)
    raise TypeError(f"not an integer: {value!r}")


@dataclass(frozen=True)
class ArgSpec:
    """One entry of ``EngineFn.a``.

    JSON shapes: ``[name, width]``, ``[name, width, enumTable]`` or
    ``[name, width, {"e": enumTable, "s": [mul, div, add]}]``.
    """

    name: str
    width: int
    enum: str | None = None
    scale: tuple[int, int, int] | None = None

    @classmethod
    def parse(cls, raw: Iterable[Any]) -> "ArgSpec":
        parts = list(raw)
        name, width = str(parts[0]), int(parts[1])
        enum = None
        scale = None
        if len(parts) > 2 and parts[2] is not None:
            extra = parts[2]
            if isinstance(extra, str):
                enum = extra
            elif isinstance(extra, dict):
                enum = extra.get("e")
                if extra.get("s") is not None:
                    mul, div, add = extra["s"]
                    scale = (int(mul), int(div), int(add))
            else:
                raise ValueError(f"bad argument spec: {raw!r}")
        return cls(name=name, width=width, enum=enum, scale=scale)


@dataclass(frozen=True)
class Bitfield:
    name: str
    mask: int
    width: int
    enum: str | None = None


@dataclass(frozen=True)
class ResultSpec:
    """One entry of ``EngineFn.r``."""

    name: str
    width: int
    mask: int | None = None
    scale: tuple[int, int, int] | None = None
    enum: str | None = None
    little_endian: bool = False
    bitfields: tuple[Bitfield, ...] = ()

    @classmethod
    def parse(cls, raw: Iterable[Any]) -> "ResultSpec":
        parts = list(raw)
        if isinstance(parts[0], str):
            name, width = str(parts[0]), int(parts[1])
            return cls(name=name, width=width)
        spec = parts[0]
        if not isinstance(spec, dict):  # pragma: no cover - defensive
            raise ValueError(f"bad result spec: {raw!r}")
        mask = _int(spec["m"]) if spec.get("m") is not None else None
        scale = None
        if spec.get("s") is not None:
            mul, div, add = spec["s"]
            scale = (int(mul), int(div), int(add))
        bitfields: list[Bitfield] = []
        for item in spec.get("bf") or []:
            bname, bmask = item[0], _int(item[1])
            # Width of a bitfield is implied by the mask length.
            bwidth = max(1, (bmask.bit_length() + 7) // 8)
            bitfields.append(
                Bitfield(
                    name=str(bname),
                    mask=bmask,
                    width=bwidth,
                    enum=item[2] if len(item) > 2 else None,
                )
            )
        width = spec.get("w")
        if width is None:
            width = max((b.width for b in bitfields), default=1)
        return cls(
            name=str(spec.get("n", "value")),
            width=int(width),
            mask=mask,
            scale=scale,
            enum=spec.get("e"),
            little_endian=spec.get("o") == "L",
            bitfields=tuple(bitfields),
        )


@dataclass(frozen=True)
class Fn:
    """A UDS function / job description (``EngineFn``)."""

    name: str
    service: int
    ident: bytes | None = None
    args: tuple[ArgSpec, ...] = ()
    results: tuple[ResultSpec, ...] = ()
    mode: str = "vm"

    @classmethod
    def parse(cls, raw: dict[str, Any]) -> "Fn":
        return cls(
            name=str(raw["n"]),
            service=int(raw["s"]),
            ident=_hex_bytes(raw.get("id")),
            args=tuple(ArgSpec.parse(a) for a in raw.get("a") or []),
            results=tuple(ResultSpec.parse(r) for r in raw.get("r") or []),
            mode=str(raw.get("p") or "vm"),
        )


@dataclass(frozen=True)
class LightMap:
    function: str
    template: bytes
    channels: dict[str, tuple[tuple[int, int], ...]]
    state_on: tuple[tuple[int, int], ...] = ()
    state_off: tuple[tuple[int, int], ...] = ()
    fixed: dict[str, bytes] = field(default_factory=dict)

    @classmethod
    def parse(cls, raw: dict[str, Any]) -> "LightMap":
        def bits(items):
            return tuple((int(off), _int(mask)) for off, mask in items or ())

        state = raw.get("state") or {}
        return cls(
            function=str(raw["function"]),
            template=_hex_bytes(raw["template"]) or b"",
            channels={k: bits(v) for k, v in (raw.get("channels") or {}).items()},
            state_on=bits(state.get("on")),
            state_off=bits(state.get("off")),
            fixed={k: (_hex_bytes(v) or b"") for k, v in (raw.get("fixed") or {}).items()},
        )


@dataclass
class Bundle:
    """A ``<SGBD>.uds.bimmerlight`` document."""

    sgbd: str
    addr: str
    jobs: dict[str, bytes]
    fns: tuple[Fn, ...]
    enums: dict[str, dict[str, int]]
    lights: LightMap | None = None

    @classmethod
    def from_json(cls, raw: dict[str, Any]) -> "Bundle":
        return cls(
            sgbd=str(raw["sgbd"]),
            addr=str(raw.get("addr", "")),
            jobs={k: (_hex_bytes(v) or b"") for k, v in (raw.get("jobs") or {}).items()},
            fns=tuple(Fn.parse(f) for f in raw.get("fns") or []),
            enums={k: {s: int(v) for s, v in table.items()} for k, table in (raw.get("enums") or {}).items()},
            lights=LightMap.parse(raw["lights"]) if raw.get("lights") else None,
        )

    def find_fn(self, name: str, service: int | None = None) -> Fn | None:
        candidates = [f for f in self.fns if f.name == name]
        if service is not None:
            exact = [f for f in candidates if f.service == service]
            if exact:
                return exact[0]
        return candidates[0] if candidates else None
