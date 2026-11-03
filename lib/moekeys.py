"""The grammar of a list of batch sizes ("keys"), in ONE place (E2 code gate, finding 10). Imported by lib/merge_moe.py and lib/moe_kernel_ab.py; the bash
twin is `_moe_keys_problem` in lib/moe.sh, and tests/test_moekeys.py feeds both the same edge cases.

A list is 1 to 20 distinct whole numbers from 1 to 65536 separated by whitespace, for example "8 16 24". It is returned sorted. Python >= 3.10, standard
library only.
"""
import re

MAX_KEYS = 20
MAX_KEY = 65536
KEY = re.compile(r"[1-9][0-9]{0,4}")


class KeyListError(ValueError):
    """A text that is not a list of batch sizes; the message names the argument and the format."""


def key_list(text, what):
    """The batch sizes of an argument, as a sorted list; anything else raises KeyListError."""
    format_hint = (f'{what} "{text}" is not a list of whitespace-separated batch sizes, e.g. "8 16 24" '
                   f"(1 to {MAX_KEYS} distinct whole numbers from 1 to {MAX_KEY})")
    words = text.split()
    if not 1 <= len(words) <= MAX_KEYS or not all(KEY.fullmatch(word) and int(word) <= MAX_KEY for word in words):
        raise KeyListError(format_hint)
    for word in words:
        if words.count(word) > 1:
            raise KeyListError(f'{format_hint}: {int(word)} is given twice')
    return sorted(int(word) for word in words)
