"""AES-GCM container used by every ``.bimmerlight`` file.

Observed layout (non-standard)::

    base64( nonce[12] || tag[16] || ciphertext[N] )

The key is a 32-byte ASCII literal that ships inside ``EdiabasKit``.  It is
used verbatim (it is *not* a hex encoding of a 16-byte key).  See
``docs/05-crypto.md`` for how it was recovered.
"""

from __future__ import annotations

import base64
import os

PACK_KEY = b"D8645993BA8BE1550000000764876174"
NONCE_LEN = 12
TAG_LEN = 16


class CryptoError(ValueError):
    pass


def _aesgcm(key: bytes):
    try:
        from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    except ImportError as exc:  # pragma: no cover - environment dependent
        raise CryptoError(
            "the 'cryptography' package is required for pack encryption"
        ) from exc
    return AESGCM(key)


def decrypt_pack(data: bytes | str, key: bytes = PACK_KEY) -> bytes:
    """Decrypt a base64 ``.bimmerlight`` payload into its JSON bytes."""
    if isinstance(data, str):
        data = data.encode()
    data = b"".join(data.split())
    try:
        raw = base64.b64decode(data, validate=True)
    except Exception as exc:
        raise CryptoError("pack is not valid base64") from exc
    if len(raw) < NONCE_LEN + TAG_LEN:
        raise CryptoError("pack is shorter than nonce + tag")
    nonce = raw[:NONCE_LEN]
    tag = raw[NONCE_LEN : NONCE_LEN + TAG_LEN]
    ciphertext = raw[NONCE_LEN + TAG_LEN :]
    try:
        return _aesgcm(key).decrypt(nonce, ciphertext + tag, None)
    except Exception as exc:
        raise CryptoError("pack authentication failed (wrong key or layout)") from exc


def encrypt_pack(plaintext: bytes, key: bytes = PACK_KEY, nonce: bytes | None = None) -> bytes:
    """Seal ``plaintext`` and return the base64 text written by the app."""
    nonce = nonce or os.urandom(NONCE_LEN)
    if len(nonce) != NONCE_LEN:
        raise ValueError("nonce must be 12 bytes")
    sealed = _aesgcm(key).encrypt(nonce, plaintext, None)
    ciphertext, tag = sealed[:-TAG_LEN], sealed[-TAG_LEN:]
    return base64.b64encode(nonce + tag + ciphertext)
