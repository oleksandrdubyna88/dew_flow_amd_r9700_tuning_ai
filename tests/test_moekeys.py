"""lib/moekeys.py: the ONE grammar of a batch-size list (E2 code gate, finding 10; the final round made the shell DELEGATE to it).

The grammar: 1 to 20 distinct whole numbers from 1 to 65536, separated by whitespace (e.g. "8 16 24"). Python (merge_moe.py check/merge, moe_kernel_ab.py decide),
the command line `moekeys.py check` and the shell's `_moe_keys_problem` (which calls that command line) must accept and refuse the same texts: the edge cases below
are fed to all three. The shell holds no grammar of its own: a test reads lib/moe.sh for it.
"""
import importlib.util
import subprocess
import sys

import pytest

from conftest import LIB, ROOT

MOEKEYS = LIB / "moekeys.py"


def load():
    spec = importlib.util.spec_from_file_location("moekeys_under_test", MOEKEYS)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def bash_accepts(text):
    """The worker's own check, as the verb and the worker call it: words split by whitespace, `_moe_keys_problem` over them."""
    done = subprocess.run(["bash", "-c", 'source "$1"; read -r -a words <<< "$2"; _moe_keys_problem "${words[@]}"', "_", str(LIB / "moe.sh"), text],
                          capture_output=True, text=True, timeout=60)
    return done.returncode == 0


def cli_accepts(text):
    """The command line the shell delegates to."""
    done = subprocess.run([sys.executable, "-I", str(MOEKEYS), "check", "--", text], capture_output=True, text=True, timeout=60)
    assert done.returncode in (0, 2), done.stderr
    return done.returncode == 0


def python_accepts(module, text):
    try:
        module.key_list(text, "--keys")
    except module.KeyListError:
        return False
    return True


EDGES = [
    "8 16 24", "1", "65536", "  8   16\t24 ", " ".join(str(n) for n in range(1, 21)),
    "", "   ", "0", "65537", "100000", "01", "-1", "1.5", "a", "8 x", "2 2", "8 16 8",
    " ".join(str(n) for n in range(1, 22)),
]


@pytest.mark.parametrize("text", EDGES)
def test_python_the_command_line_and_the_worker_agree_on_every_edge_case(text):
    expected = python_accepts(load(), text)
    assert cli_accepts(text) == expected, repr(text)
    assert bash_accepts(text) == expected, repr(text)


def test_the_accepted_list_is_sorted_and_the_refusal_names_the_format():
    module = load()
    assert module.key_list("24  8 16", "--keys") == [8, 16, 24]
    with pytest.raises(module.KeyListError) as caught:
        module.key_list("8 x", "--keys")
    assert str(caught.value) == '--keys "8 x" is not a list of whitespace-separated batch sizes, e.g. "8 16 24" (1 to 20 distinct whole numbers from 1 to 65536)'
    with pytest.raises(module.KeyListError) as twice:
        module.key_list("2 2", "--keys")
    assert "2 is given twice" in str(twice.value)


def test_both_programs_use_this_module_and_hold_no_grammar_of_their_own():
    for program in ("merge_moe.py", "moe_kernel_ab.py"):
        text = (LIB / program).read_text()
        assert "import moekeys" in text, program
        assert "def key_list" in text and "moekeys.key_list" in text, program
        assert "words = text.split()" not in text, f"{program} still parses a key list itself"


def test_the_shell_holds_no_batch_key_grammar_of_its_own_and_calls_the_module():
    source = (LIB / "moe.sh").read_text()
    assert 'moekeys.py" check' in source, "the worker calls lib/moekeys.py"
    for second_grammar in ("{0,4}", "-gt 65536", "-gt 20 ]", "given twice"):
        assert second_grammar not in source, f"lib/moe.sh still holds part of a grammar: {second_grammar}"


def test_the_command_line_names_the_option_and_the_format_and_exits_2():
    done = subprocess.run([sys.executable, "-I", str(MOEKEYS), "check", "--what=--rule-keys", "--", "8 x"], capture_output=True, text=True, timeout=60)
    assert done.returncode == 2
    assert done.stderr.strip() == '--rule-keys "8 x" is not a list of whitespace-separated batch sizes, e.g. "8 16 24" (1 to 20 distinct whole numbers from 1 to 65536)'
