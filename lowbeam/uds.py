"""Transport framing helpers and UDS response decoding."""

from __future__ import annotations

from typing import Any

from .model import Bundle, ResultSpec

#: Number of service bytes in front of the payload for common positive replies.
RESPONSE_HEADER = {0x62: 3, 0x5A: 2, 0x61: 2, 0x71: 4, 0xA0: 3}


def ediabas_frame(payload: bytes, dest: int, source: int = 0xF1) -> bytes:
    """Wrap a UDS payload in the K-line/DS2 frame used by Ediabas.

    ``len`` is the payload length; when it exceeds 0x3F a segmented transport
    has to be used instead.  The checksum is the wrapping byte sum over every
    byte of the frame (including the header): ``reduce(0, &+)``.
    """
    if len(payload) > 0x3F:
        raise ValueError("payload too long for a single Ediabas frame")
    frame = bytes([0x80 | len(payload), dest & 0xFF, source & 0xFF]) + payload
    return frame + bytes([sum(frame) & 0xFF])


def _decode(raw: int, spec: ResultSpec, enums: dict[str, dict[str, int]]) -> Any:
    if spec.mask:
        raw &= spec.mask
    value: Any = raw
    if spec.scale:
        mul, div, add = spec.scale
        scaled = raw * mul / div + add
        value = int(scaled) if float(scaled).is_integer() else scaled
    if spec.enum and spec.enum in enums:
        for symbol, number in enums[spec.enum].items():
            if number == raw:
                return symbol
    return value


def _ascii(chunk: bytes) -> str:
    return chunk.decode("ascii", "replace").strip("\x00 ")


def _builtin(function: str, data: bytes) -> dict[str, Any] | None:
    """Parsers for jobs that have no ``fns`` entry (see CONTRACT.md)."""
    if data and data[0] == 0x62 and len(data) >= 3:
        did = data[1:3]
        body = data[3:]
        if function == "IDENT" and did == b"\xf1\x50":
            return {"SGBD_HEX": body.hex().upper()}
        if function in ("STATUS_VIN_LESEN", "STATUS_FAHRGESTELLNUMMER") and did == b"\xf1\x90":
            raw = body[:17]
            vin = "0" * 17 if all(b in (0xFF, 0x00) for b in raw) else _ascii(raw)
            return {"VIN": vin}
        if function in ("STATUS_VCM_GET_FA", "C_FA_LESEN", "C_FA_AUFTRAG") and did in (b"\x3f\x06", b"\x3f\x00"):
            text = _ascii(body)
            parts = [p for p in text.replace(";", "|").split("|") if p]
            names = (
                "STAT_TYP_SCHLUESSEL",
                "STAT_BAUREIHE",
                "STAT_ZEITKRITERIUM",
                "STAT_LACKCODE",
                "STAT_POLSTERCODE",
                "STAT_SALAPA",
            )
            if len(parts) >= 6:
                return dict(zip(names, parts[:6]))
            return {"FA": text}
    if function == "C_FG_LESEN" and data and data[0] == 0x5A:
        return {"VIN": _ascii(data[2:19])}
    return None


def parse_response(bundle: Bundle, function: str, data: bytes) -> dict[str, Any]:
    """Decode a positive UDS response using the ``r`` spec of a function."""
    builtin = _builtin(function, data)
    if builtin is not None:
        return builtin
    fn = bundle.find_fn(function, service=None) or bundle.find_fn(function, service=data[0]) or bundle.find_fn(function, service=data[0])
    if fn is None:
        raise KeyError(f"{bundle.sgbd} has no function {function!r}")
    offset = RESPONSE_HEADER.get(data[0], 1)
    result: dict[str, Any] = {}
    for spec in fn.results:
        if offset + spec.width > len(data):
            break
        chunk = data[offset : offset + spec.width]
        offset += spec.width
        raw = int.from_bytes(chunk, "little" if spec.little_endian else "big")
        if spec.bitfields:
            for field in spec.bitfields:
                bits = (raw & field.mask) // (field.mask & -field.mask)
                if field.enum and field.enum in bundle.enums:
                    symbol = next(
                        (s for s, n in bundle.enums[field.enum].items() if n == bits),
                        bits,
                    )
                    result[field.name] = symbol
                else:
                    result[field.name] = bits
        else:
            result[spec.name] = _decode(raw, spec, bundle.enums)
    return result
