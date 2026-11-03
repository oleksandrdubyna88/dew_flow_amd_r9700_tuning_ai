"""The grammar of a list of batch sizes ("keys"), in ONE place (E2 code gate, finding 10 and the final round). Imported by lib/merge_moe.py and lib/moe_kernel_ab.py;
the shell calls it through the command line below (`_moe_keys_problem` in lib/moe.sh delegates to it: there is no second grammar to drift).

  moekeys.py check [--what <label>] -- "<text>"     exit 0 for a valid list; else the message on stderr and exit 2 

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


def main(argv=None):
    """The command line the shell uses: `check [--what <label>] -- <text>`."""
    import argparse
    import sys
    parser = argparse.ArgumentParser(prog="moekeys.py", description=__doc__)
    sub = parser.add_subparsers(dest="cmd", required=True)
    check = sub.add_parser("check", help="is this text a list of batch sizes")
    check.add_argument("--what", default="the batch sizes", help="what the text is, for the message (an option name)")
    check.add_argument("text")
    args = parser.parse_args(argv)
    try:
        key_list(args.text, args.what)
    except KeyListError as error:
        print(error, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    import sys
    sys.exit(main())
