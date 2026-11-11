"""Request encoder for the UdsEngine JSON packs.

The rules implemented here come from ``CONTRACT.md`` (shipped inside
``EdiabasKit.framework``) and were cross-checked against every decrypted pack.
See ``docs/04-uds-engine.md`` for the long-form description.
"""

from __future__ import annotations

from typing import Any, Iterable, Mapping

from .model import ArgSpec, Bundle, Fn, LightMap

ROUTINE_SUBFN = {"STR": 0x01, "STPR": 0x02, "RRR": 0x03}
IO_CONTROL = {"RCTECU": 0x00, "RTD": 0x01, "FCS": 0x02, "STA": 0x03}
DIAG_SESSION = {
    "DEFAULT": 0x01,
    "ECUPM": 0x02,
    "ECUEXTDIAG": 0x03,
    "ECUSSDS": 0x04,
    "ECUADS": 0x05,
    "SUPPLIER": 0x60,
}
TRUTHY = {"1", "on", "ein", "true", "yes", "an"}


class EncodeError(ValueError):
    pass


def _param(value: Any, params: Mapping[str, Any]) -> Any:
    if isinstance(value, str) and value.startswith("{") and value.endswith("}"):
        name = value[1:-1]
        if name not in params:
            raise EncodeError(f"missing parameter {name!r}")
        return params[name]
    return value


def _is_truthy(value: Any) -> bool:
    if isinstance(value, bool):
        return value
    if isinstance(value, (int, float)):
        return value != 0
    return str(value).strip().lower() in TRUTHY


def _integer(value: Any, enum: Mapping[str, int] | None = None) -> int:
    if isinstance(value, bool):
        return int(value)
    if isinstance(value, int):
        return value
    text = str(value).strip()
    if enum and text in enum:
        return enum[text]
    lowered = text.lower()
    if lowered in ("ein", "on", "an", "true"):
        return 1
    if lowered in ("aus", "off", "false"):
        return 0
    try:
        return int(text, 0)
    except ValueError as exc:
        raise EncodeError(f"cannot convert {value!r} to an integer") from exc


def _encode_value(value: Any, spec: ArgSpec, bundle: Bundle) -> bytes:
    enum = bundle.enums.get(spec.enum) if spec.enum else None
    number = _integer(value, enum)
    # ``s`` describes how a *response* value is displayed (``raw*mul/div+add``).
    # Argument values shipped in the packs are already raw ECU units, so no
    # inverse scaling is applied here; see docs/04-uds-engine.md.
    if not 0 <= number < (1 << (8 * spec.width)):
        raise EncodeError(
            f"{spec.name}={number} does not fit in {spec.width} byte(s)"
        )
    return number.to_bytes(spec.width, "big")


def _encode_args(values: Iterable[Any], specs: Iterable[ArgSpec], bundle: Bundle) -> bytes:
    values = list(values)
    specs = list(specs)
    if values and isinstance(values[0], str) and any(values[0] == s.name for s in specs):
        # Named-argument form used by the LHM2 brightness/current channels:
        # ("KANAL3_HELLIGKEIT", 100) selects one field of a 14-byte frame.
        by_name = {s.name: s for s in specs}
        positions: dict[str, int] = {}
        offset = 0
        for spec in specs:
            positions[spec.name] = offset
            offset += spec.width
        body = bytearray(offset)
        for name, value in zip(values[0::2], values[1::2]):
            spec = by_name[str(name)]
            start = positions[spec.name]
            body[start : start + spec.width] = _encode_value(value, spec, bundle)
        return bytes(body)
    if len(values) != len(specs):
        raise EncodeError(f"expected {len(specs)} argument(s), got {len(values)}")
    return b"".join(_encode_value(v, s, bundle) for v, s in zip(values, specs))


def _raw_bytes(value: Any, bundle: Bundle) -> bytes:
    """Encode an argument that has no schema entry."""
    if isinstance(value, bool):
        return b"\x01" if value else b"\x00"
    if isinstance(value, int):
        if value < 0:
            raise EncodeError("negative raw argument")
        return value.to_bytes(max(1, (value.bit_length() + 7) // 8), "big")
    text = str(value).strip()
    lowered = text.lower()
    if lowered in ("ein", "on", "an", "true"):
        return b"\x01"
    if lowered in ("aus", "off", "false"):
        return b"\x00"
    for table in bundle.enums.values():
        if text in table:
            return bytes([table[text]])
    digits = text[2:] if text.lower().startswith("0x") else text
    if digits and all(c in "0123456789abcdefABCDEF" for c in digits):
        if len(digits) % 2:
            digits = "0" + digits
        return bytes.fromhex(digits)
    raise EncodeError(f"cannot encode raw argument {value!r}")


def _replace_tail(base: bytes, body: bytes) -> bytes:
    """Overwrite trailing placeholder bytes; append when no placeholder fits."""
    if body and len(base) >= len(body) and base[-len(body) :] == b"\x00" * len(body):
        # Bases such as ``2f4501030000`` keep a fixed control byte before the
        # argument bytes (``2f 45 01 03`` + two placeholder bytes).
        return base[: -len(body)] + body
    return base + body


def light_frame(lights: LightMap, channel: str, on: bool = True) -> bytes:
    """Build a light frame from the template and channel bit map."""
    if channel not in lights.channels:
        raise EncodeError(f"unknown light channel {channel!r}")
    frame = bytearray(lights.template)
    for offset, mask in lights.channels[channel]:
        if offset >= len(frame):
            raise EncodeError(f"channel {channel!r} offset {offset} outside template")
        frame[offset] |= mask
    for offset, mask in lights.state_on if on else lights.state_off:
        if offset >= len(frame):
            raise EncodeError(f"state offset {offset} outside template")
        frame[offset] |= mask
    return bytes(frame)


def _special(bundle: Bundle, function: str, args: list[Any]) -> bytes | None:
    if function == "DIAGNOSE_MODE":
        first = args[0] if args else "DEFAULT"
        if isinstance(first, str) and first in DIAG_SESSION:
            session = DIAG_SESSION[first]
        else:
            session = _integer(first)
        return bytes([0x10, session])
    if function == "DIAGNOSE_AUFRECHT":
        return bundle.jobs.get("DIAGNOSE_AUFRECHT", b"\x3e\x01")
    if function == "DIAGNOSE_ENDE":
        if bundle.lights and "DIAGNOSE_ENDE" in bundle.lights.fixed:
            return bundle.lights.fixed["DIAGNOSE_ENDE"]
        return bundle.jobs.get("DIAGNOSE_ENDE", b"\x10\x01")
    if function == "COMMUNICATION_CONTROL":
        return b"\x28" + b"".join(_raw_bytes(a, bundle) for a in args)
    if function == "IO_RETURN_CONTROL":
        return b"\x2f" + b"".join(_raw_bytes(a, bundle) for a in args)
    if function == "RAW_UDS":
        return b"".join(_raw_bytes(a, bundle) for a in args)
    return None


def encode_action(
    bundle: Bundle,
    function: str,
    args: Iterable[Any] = (),
    params: Mapping[str, Any] | None = None,
) -> bytes:
    """Encode one action-map entry into a UDS request payload.

    ``args`` may still contain ``{param_x}`` placeholders; pass ``params`` to
    resolve them (the light-show packs do this).
    """
    params = params or {}
    values = [_param(a, params) for a in args]

    special = _special(bundle, function, values)
    if special is not None:
        return special

    # Light-map driven functions come first: they ignore the generic job base.
    if bundle.lights and function == bundle.lights.function:
        if not values:
            # ``ALL_OFF`` carries no channel: emit the bare template.
            frame = bytearray(bundle.lights.template)
            for offset, mask in bundle.lights.state_off:
                frame[offset] |= mask
            return bytes(frame)
        channel = str(values[0])
        if channel not in bundle.lights.channels:
            raise EncodeError(
                f"{bundle.sgbd} has no light channel {channel!r}"
            )
        on = _is_truthy(values[1]) if len(values) > 1 else True
        return light_frame(bundle.lights, channel, on)

    base = bundle.jobs.get(function)
    if base is None:
        fn = bundle.find_fn(function)
        if fn is None:
            raise EncodeError(f"unknown function {function!r} for {bundle.sgbd}")
        base = bytes([fn.service])
        if fn.ident:
            base += fn.ident
        return _encode_args(values, fn.args, bundle)

    if values and values[0] == "ARG":
        if len(values) < 2:
            raise EncodeError("ARG dispatch without a function name")
        target = str(values[1])
        fn = bundle.find_fn(target, service=base[0] if base else None)
        if fn is None:
            raise EncodeError(f"unknown ARG target {target!r} for {bundle.sgbd}")
        rest = values[2:]
        prefix = base
        if base and base[0] == 0x31:
            if not rest:
                raise EncodeError("STEUERN_ROUTINE needs a routine subfunction")
            sub = rest[0]
            if isinstance(sub, str) and sub in ROUTINE_SUBFN:
                subfn = ROUTINE_SUBFN[sub]
            else:
                subfn = _integer(sub)
            rest = rest[1:]
            prefix = bytes([base[0], subfn])
            if fn.ident:
                prefix += fn.ident
            if not rest:
                # ``31 02 DID`` (stop routine) carries no further arguments.
                return prefix
        elif base and base[0] == 0x2F:
            if not rest:
                raise EncodeError("STEUERN_IO needs an IO control parameter")
            control = rest[0]
            if isinstance(control, str) and control in IO_CONTROL:
                ioparam = IO_CONTROL[control]
            else:
                ioparam = _integer(control)
            rest = rest[1:]
            prefix = base + (fn.ident or b"") + bytes([ioparam])
            if not rest:
                # ``2F DID <control>`` has no payload for return-to-ECU/reset.
                return prefix
        elif fn.ident:
            prefix += fn.ident
        elif len(base) > 1:
            prefix = base
        body = _encode_args(rest, fn.args, bundle)
        return _replace_tail(prefix, body)

    fn = bundle.find_fn(function, service=base[0] if base else None)
    if fn is not None:
        prefix = base
        if fn.ident and len(base) <= 1:
            prefix += fn.ident
        body = _encode_args(values, fn.args, bundle)
        return _replace_tail(prefix, body)

    body = b"".join(_raw_bytes(v, bundle) for v in values)
    return _replace_tail(base, body)
