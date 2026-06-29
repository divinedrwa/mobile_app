#!/usr/bin/env python3
"""Remove `const` from widget constructors that reference GuardTokens runtime getters."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib" / "features" / "guard"
GETTERS = re.compile(
    r"GuardTokens\.(?:guardAccentDeep|guardAccent|guardPrimary|success|textSecondary|dangerBrand)"
)

WIDGETS = (
    "IconThemeData",
    "TextStyle",
    "Text",
    "Icon",
    "BorderSide",
    "InputDecoration",
    "BoxDecoration",
    "LinearGradient",
    "RadialGradient",
    "SweepGradient",
    "SizedBox",
    "Center",
    "CircularProgressIndicator",
    "AlwaysStoppedAnimation",
    "Padding",
    "DecoratedBox",
    "Container",
)


def find_matching_paren(s: str, open_idx: int) -> int:
    depth = 0
    i = open_idx
    while i < len(s):
        c = s[i]
        if c == "(":
            depth += 1
        elif c == ")":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return len(s) - 1


def strip_const_in_block(content: str) -> str:
    for name in WIDGETS:
        pattern = re.compile(rf"\bconst ({re.escape(name)}\()", re.MULTILINE)
        while True:
            m = pattern.search(content)
            if not m:
                break
            start = m.start()
            open_paren = m.end() - 1
            end = find_matching_paren(content, open_paren)
            block = content[start : end + 1]
            if GETTERS.search(block):
                new_block = block.replace("const ", "", 1)
                content = content[:start] + new_block + content[end + 1 :]
            else:
                # skip this match
                content = content[: m.start()] + content[m.start() + 6 :] + content[m.end() - 1 :]
                # bad skip - let me use different approach
                break
    return content


def strip_const_iterative(content: str) -> str:
    changed = True
    while changed:
        changed = False
        for name in WIDGETS:
            pattern = re.compile(rf"\bconst ({re.escape(name)}\()", re.MULTILINE)
            for m in list(pattern.finditer(content)):
                start = m.start()
                open_paren = m.end() - 1
                end = find_matching_paren(content, open_paren)
                block = content[start : end + 1]
                if GETTERS.search(block):
                    new_block = block.replace("const ", "", 1)
                    content = content[:start] + new_block + content[end + 1 :]
                    changed = True
                    break
            if changed:
                break
    return content


def main() -> None:
    n = 0
    for path in sorted(ROOT.rglob("*.dart")):
        orig = path.read_text(encoding="utf-8")
        fixed = strip_const_iterative(orig)
        if fixed != orig:
            path.write_text(fixed, encoding="utf-8")
            n += 1
            print(path.relative_to(ROOT.parent.parent))
    print(f"Fixed {n} files.")


if __name__ == "__main__":
    main()
