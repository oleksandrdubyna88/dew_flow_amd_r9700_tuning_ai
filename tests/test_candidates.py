"""config/coarse_candidates.json: the 82 coarse candidates of the MoE chunk tuner (E2.S1, scenarios C1-C3)."""
import hashlib
import importlib.util
import itertools
import json

from conftest import LIB, ROOT

CANDIDATES = ROOT / "config" / "coarse_candidates.json"
PUBLISHED_SHA256 = "d23483de2f75986046f3d36817cefa6cd3ea4a787a5b9c3c6ad2cee556d79273"
BLOCKS = (32, 64, 128)
WARPS = (2, 4, 8)
# The one entry outside the product: the batch-size-1 winner of 2026-10-26.
BATCH_1_WINNER = {"BLOCK_SIZE_M": 16, "BLOCK_SIZE_N": 16, "BLOCK_SIZE_K": 64, "GROUP_SIZE_M": 1, "num_warps": 1, "num_stages": 2, "waves_per_eu": 4}


def entries():
    return json.loads(CANDIDATES.read_text())


def product():
    """The 81 configs of decision 4: BLOCK_SIZE_M/N/K in {32, 64, 128} x num_warps in {2, 4, 8}, GROUP_SIZE_M 1, num_stages 2, waves_per_eu 0."""
    return [{"BLOCK_SIZE_M": m, "BLOCK_SIZE_N": n, "BLOCK_SIZE_K": k, "GROUP_SIZE_M": 1, "num_warps": warps, "num_stages": 2, "waves_per_eu": 0}
            for m, n, k, warps in itertools.product(BLOCKS, BLOCKS, BLOCKS, WARPS)]


def test_the_file_is_the_81_config_product_plus_the_batch_size_1_winner():
    found, expected = entries(), product()
    assert len(expected) == 81, "the product itself is alive: 3 x 3 x 3 x 3 configs"
    assert all(entry in found for entry in expected)
    assert len(found) == 82
    assert [entry for entry in found if entry not in expected] == [BATCH_1_WINNER]


def test_every_candidate_passes_the_merge_field_check():
    spec = importlib.util.spec_from_file_location("merge_moe_for_candidates", LIB / "merge_moe.py")
    merge = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(merge)
    assert merge.FIELDS and all(merge.FIELDS <= entry.keys() for entry in entries())


def test_the_file_is_the_published_one_byte_for_byte():
    """A silent edit is a red test; a deliberate one updates PUBLISHED_SHA256 with its reason."""
    assert hashlib.sha256(CANDIDATES.read_bytes()).hexdigest() == PUBLISHED_SHA256
