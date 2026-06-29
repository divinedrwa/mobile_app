#!/usr/bin/env python3
"""Remove `const` on lines referencing DesignColors / ActionColors getters."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib"
TOKEN = re.compile(r"(DesignColors|ActionColors)\.")


def fix_content(content: str) -> str:
    lines = content.split("\n")
    out: list[str] = []
    for i, line in enumerate(lines):
        if TOKEN.search(line):
            # Drop const on this line.
            line = re.sub(r"\bconst\s+", "", line)
            # If previous non-empty line is only "const" wrapper start, un-const it too.
            if i > 0:
                prev = out[-1]
                if re.search(r"\bconst\s+\w", prev) and TOKEN.search(line):
                    out[-1] = re.sub(r"\bconst\s+", "", prev)
        out.append(line)

    content = "\n".join(out)

    # const Map / const { ... DesignColors
    content = re.sub(
        r"const (\{[^}]*?(?:DesignColors|ActionColors)[^}]*?\})",
        r"\1",
        content,
        flags=re.DOTALL,
    )
    content = re.sub(
        r"const (\[[^\]]*?(?:DesignColors|ActionColors)[^\]]*?\])",
        r"\1",
        content,
        flags=re.DOTALL,
    )
    content = re.sub(
        r"const \(([^)]*(?:DesignColors|ActionColors)[^)]*)\)",
        r"(\1)",
        content,
        flags=re.DOTALL,
    )
    return content


def main() -> None:
    n = 0
    for dart in ROOT.rglob("*.dart"):
        if "/theme/" in str(dart):
            continue
        orig = dart.read_text(encoding="utf-8")
        fixed = fix_content(orig)
        if fixed != orig:
            dart.write_text(fixed, encoding="utf-8")
            n += 1
    print(f"Patched {n} files.")


if __name__ == "__main__":
    main()
