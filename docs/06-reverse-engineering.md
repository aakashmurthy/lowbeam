# Reverse-engineering notes

## Inputs

* `com.bimmerlight.prod_v3.9_und3fined.ipa`
  (10,983,487 bytes,
  sha256 `42b32d53a2de66e9471d53a25228901a26f1910a7bedcb5aa0e388736501fec6`).
* `Payload/BimmerLight.app/` — main binary, `Frameworks/BimmerLightKit.framework`,
  `Frameworks/EdiabasKit.framework`, vendor frameworks, `WidgetExtension.appex`.
* `EdiabasKit.framework/CONTRACT.md` — the vendor's own format/behaviour
  specification (UTF-8, originally Cyrillic).  It is the source of the
  UdsEngine rules and of the 1110-case acceptance table.

## Tooling

| tool | use |
| --- | --- |
| LIEF 1.0 (`lief`) | Mach-O parsing, sections, export trie, chained fixups |
| Capstone 5 | ARM64 disassembly |
| `swift-demangle-wasm` (npm) | demangling 2760 EdiabasKit + 431 BimmerLightKit symbols |
| `strings` (msys2) | string inventory per binary |
| Ghidra 12.1.4 | not usable for Mach-O on this Windows host |

### Ghidra limitation

REA's Windows Ghidra provider rejects Mach-O:

```
target_format_unsupported
Windows Ghidra P0 accepts native PE and explicitly selected raw 6502 targets only.
```

So the analysis used LIEF + Capstone directly.  The helper
`analysis/disasm_tool.py` loads the Mach-O, resolves `__stubs` → GOT through
LIEF's chained-fixup bindings (each stub is `adrp/ldr/br`), annotates `BL`
targets with demangled symbol names, resolves `ADRP+ADD/LOAD` literal
addresses, and prints `__cstring` strings.

### Symbol resolution

For Swift symbols in these binaries LIEF reports `symbol.value == 0`; the real
address is `symbol.export_info.address` (origin `DYLD_EXPORT`).  That is why
naive symbol tables look empty.  The main app binary is stripped and exports a
single symbol, so its behaviour was recovered from strings, Swift metadata and
cross-references into the frameworks.

## Findings that mattered

1. **AES key location.** Both `decryptDownloadedEncryptedData` and `sealGCM`
   compute `0x11c020` and pass a 32-byte tagged Swift string to
   `SymmetricKey(data:)`.  See `04-crypto.md`.
2. **Tag before ciphertext.** The helper at `0x7b19c` slices nonce, tag,
   ciphertext in that order, unlike CryptoKit's default.
3. **Checksum is addition.** `CONTRACT.md` says `reduce(0, &+)`; the contract
   example (`... 64` → `66`) confirms a wrapping byte sum, not XOR.
4. **Job bases contain placeholders.** Several bases end in zero bytes that
   the encoder overwrites (`2F 45 01 03 00 00`), while others are complete
   requests that get bytes appended (`31 01 F0 12`).
5. **`ARG` dispatch is service-aware.** The same function name can exist at
   services 0x22/0x2E/0x31; the base's first byte selects the right overload.
6. **Three pseudo-jobs are needed for lighting.** `DIAGNOSE_MODE`,
   `DIAGNOSE_AUFRECHT` and `DIAGNOSE_ENDE` never appear in `jobs`; their
   behaviour is hard-coded (including per-ECU `DIAGNOSE_ENDE` frames in
   `lights.fixed`).
7. **Light frames are OR-maps.** Channel bits and `state.on/off` bytes are
   OR-ed into a template; `ALL_OFF` is the bare template.

## Reproduction

```bash
cd opensource
python -m pytest -q          # 10 tests
python -m lowbeam list   # 51 action maps
```

The sweep test encodes all 1554 actions and pins the six known gaps, so any
regression in the rules or the data shows up immediately.

## Not reconstructed

The shipped IPA contains no source, asset catalogs beyond `Assets.car`, or
SwiftUI view bodies.  Screen layout and copy would have to be rebuilt from the
binary; this repository focuses on the data formats and the diagnostics engine,
which are the parts that are fully recoverable and independently testable.
