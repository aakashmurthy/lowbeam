import json
from pathlib import Path

import pytest

from lowbeam import Repo, decrypt_pack, ediabas_frame, encode_action, parse_response

ROOT = Path(__file__).resolve().parent.parent


@pytest.fixture(scope="session")
def repo() -> Repo:
    return Repo(ROOT)


def test_crypto_roundtrip():
    plain = b'{"hello":"world"}'
    from lowbeam import encrypt_pack

    sealed = encrypt_pack(plain, nonce=b"\x00" * 12)
    assert decrypt_pack(sealed) == plain


def test_decrypt_shipped_manifest():
    sealed = (ROOT / "samples" / "manifest.bimmerlight").read_bytes()
    data = json.loads(decrypt_pack(sealed))
    assert data["cdn_base"] == "https://cdn.bimmerlight.com"
    assert set(data["sections"]) == {"information", "mappings", "packs", "uds"}


# --- CONTRACT.md acceptance examples -------------------------------------

def test_contract_fem20_light_output(repo: Repo):
    bundle = repo.bundle("FEM_20")
    payload = encode_action(
        bundle, "STEUERN_LEUCHTENAUSGANG_DIGITAL", ["0x01", "1"]
    )
    assert payload.hex().upper() == "2F4501030101"


def test_contract_komb_g11_trigger(repo: Repo):
    bundle = repo.bundle("KOMB_G11")
    payload = encode_action(
        bundle,
        "STEUERN_CC_MELDUNG_TRIGGERN",
        ["0x01", "0xfc", "0x32", "0x21"],
    )
    assert payload.hex().upper() == "3101F01201FC3221"


def test_contract_lcm_status(repo: Repo):
    bundle = repo.bundle("LCM")
    payload = encode_action(bundle, "STATUS_VORGEBEN", ["AL_L"])
    assert payload.hex().upper() == "D0100C000000004000000000000000"


def test_contract_rem20_light_output(repo: Repo):
    bundle = repo.bundle("REM_20")
    payload = encode_action(
        bundle, "STEUERN_LEUCHTENAUSGANG_DIGITAL", ["SL_L", "1"]
    )
    assert payload.hex().upper() == "2E45011401"


def test_contract_frm3_digital_light(repo: Repo):
    bundle = repo.bundle("FRM3")
    payload = encode_action(bundle, "STEUERN_DIGITAL_LICHT", ["AL_L", "1"])
    assert payload.hex().upper() == "2F01040364"


def test_contract_ediabas_frame():
    payload = bytes.fromhex("2ED54200050064")
    assert ediabas_frame(payload, 0x40).hex().upper() == "8740F12ED5420005006466"


# --- data invariants ------------------------------------------------------

def test_every_mapping_action_encodes(repo: Repo):
    failures = []
    total = 0
    # Channels referenced by the packs but absent from the shipped light maps.
    known_gaps = {
        ("FRM3", "BRAKE_LEFT_2"),
        ("FRM3", "BRAKE_RIGHT_2"),
        ("FRM3", "CORNERING_LEFT"),
        ("FRM3", "CORNERING_RIGHT"),
        ("FRM3", ""),
        ("REM_20", ""),
    }
    params = {
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
    for sgbd, actions in repo.mappings.items():
        for action in actions:
            total += 1
            try:
                repo.encode(sgbd, action["function"], action["args"], params)
            except Exception as exc:  # noqa: BLE001 - collect for the report
                failures.append((sgbd, action["command"], str(exc)))
    assert total == 1554
    assert {(s, c) for s, c, _ in failures} == known_gaps, failures
    assert len(failures) == len(known_gaps)


def test_data_counts(repo: Repo):
    assert len(repo.mappings) == 51
    assert len(repo.bundles) == 52
    assert len(repo.packs) == 9
    assert len(repo.chassis) == 5894
    assert len(repo.ecu_modules) == 439
    assert len(repo.salapa) == 5614
    assert repo.manifest["sections"]["mappings"]["count"] == 51
    assert repo.manifest["sections"]["uds"]["count"] == 52


def test_light_channels_fit_templates(repo: Repo):
    for sgbd, bundle in repo.bundles.items():
        if not bundle.lights:
            continue
        size = len(bundle.lights.template)
        for channel, bits in bundle.lights.channels.items():
            for offset, _ in bits:
                assert offset < size, (sgbd, channel, offset)


def test_parse_ident_and_vin(repo: Repo):
    bundle = repo.bundle("FEM_20")
    assert parse_response(bundle, "IDENT", bytes.fromhex("62F150") + b"ABC") == {
        "SGBD_HEX": "414243"
    }
    assert parse_response(
        bundle, "STATUS_FAHRGESTELLNUMMER", bytes.fromhex("62F190") + b"\xff" * 17
    ) == {"VIN": "0" * 17}
    assert parse_response(
        bundle, "STATUS_VIN_LESEN", bytes.fromhex("62F190") + b"WBA1234567890ABCD"
    ) == {"VIN": "WBA1234567890ABCD"}


def test_parse_result_spec(repo: Repo):
    bundle = repo.bundle("KOMBSP18")
    fn = bundle.find_fn("ADC_LESEN")
    assert fn and fn.results
    width = sum(spec.width for spec in fn.results)
    data = bytes([0x62, 0x00, 0x00]) + bytes(range(width))
    parsed = parse_response(bundle, "ADC_LESEN", data)
    assert parsed[fn.results[0].name] == int.from_bytes(bytes([0, 1]), "big")
