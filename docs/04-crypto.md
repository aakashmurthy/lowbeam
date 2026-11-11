# Pack crypto

Every `*.bimmerlight` file in the app bundle (and every file downloaded from
the CDN) is base64 text around an AES-256-GCM container.

## Container layout

```
plaintext   = UTF-8 JSON
nonce       = 12 random bytes
sealed      = AES-GCM(key, nonce, plaintext, aad = none)
              = ciphertext || tag16
file bytes  = base64( nonce || tag || ciphertext )
```

This is **not** CryptoKit's default `nonce || ciphertext || tag` order: the
16-byte tag sits immediately after the nonce, before the ciphertext.  The
app's `open` helper at `EdiabasKit` `0x7b19c` enforces `count >= 29` and slices
`0..<12`, `12..<28`, `28...` accordingly.

## Key

```python
PACK_KEY = b"D8645993BA8BE1550000000764876174"   # 32 ASCII bytes
```

The 32-byte UTF-8 string literal lives at Mach-O file offset `0x11c020`.
It is used verbatim as the AES-256 key; do **not** hex-decode it.

## How it was recovered

`EdiabasKit` exports three relevant functions (addresses are file offsets in
the thin arm64 Mach-O):

| address | symbol |
| --- | --- |
| `0x79bac` | `decryptDownloadedEncryptedData(_: Data) throws -> Data` |
| `0x7a49c` | `saveEncryptedGCM(named:data:fileExtension:) throws -> String` |
| `0x7b4e0` | `sealGCM(_: Data) throws -> Data` |

All three compute the same literal address:

```asm
adrp x8, #0x11c000
add  x8, x8, #0x40
sub  x8, x8, #0x20        ; x8 = 0x11c020
orr  x1, x8, #0x8000000000000000   ; tagged Swift string pointer
mov  x0, #0x20
movk x0, #0xd000, lsl #48          ; 32-byte String literal
```

`SymmetricKey(data:)` is then called with the literal's UTF-8 bytes, followed
by `AES.GCM.open` / `AES.GCM.seal`.  Dumping `0x11c020` gave the ASCII key
above; all 116 shipped files decrypt with it, which is the strongest possible
confirmation.

## Python API

```python
from lowbeam import decrypt_pack, encrypt_pack

plain = decrypt_pack(open("manifest.bimmerlight", "rb").read())
sealed = encrypt_pack(plain, nonce=b"\x00" * 12)   # deterministic for tests
```

`encrypt_pack` uses a random nonce by default.  The tests decrypt
`samples/manifest.bimmerlight` and compare the resulting manifest with
`data/manifest.json`.

## Note on the "sha256 expected=" string

`HTTPClient.requestEncrypted(..., expectedPlaintextSHA256:)` downloads the
sealed file, decrypts it, and compares the SHA-256 of the **plaintext** with
the manifest entry.  The manifest's `sha256` fields are therefore hashes of the
decrypted JSON, not of the base64 file.
