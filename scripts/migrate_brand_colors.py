#!/usr/bin/env python3
"""Replace common hardcoded brand hex literals with DesignColors / ActionColors getters.

Skips lib/theme/ and lib/core/theme/ (token registries).
Removes `const` before Color(...) when the replacement is a getter.
"""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "lib" / "features"

REPLACEMENTS = [
    (r"const Color\(0xFF16A34A\)", "DesignColors.accent"),
    (r"Color\(0xFF16A34A\)", "DesignColors.accent"),
    (r"const Color\(0xFF22C55E\)", "DesignColors.success"),
    (r"Color\(0xFF22C55E\)", "DesignColors.success"),
    (r"const Color\(0xFF10B981\)", "DesignColors.success"),
    (r"Color\(0xFF10B981\)", "DesignColors.success"),
    (r"const Color\(0xFF059669\)", "DesignColors.success"),
    (r"Color\(0xFF059669\)", "DesignColors.success"),
    (r"const Color\(0xFF00897B\)", "DesignColors.primary"),
    (r"Color\(0xFF00897B\)", "DesignColors.primary"),
    (r"const Color\(0xFF0D9488\)", "DesignColors.primary"),
    (r"Color\(0xFF0D9488\)", "DesignColors.primary"),
    (r"const Color\(0xFF2563EB\)", "DesignColors.info"),
    (r"Color\(0xFF2563EB\)", "DesignColors.info"),
    (r"const Color\(0xFF3B82F6\)", "DesignColors.info"),
    (r"Color\(0xFF3B82F6\)", "DesignColors.info"),
    (r"const Color\(0xFF0EA5E9\)", "DesignColors.info"),
    (r"Color\(0xFF0EA5E9\)", "DesignColors.info"),
    (r"const Color\(0xFF0284C7\)", "DesignColors.info"),
    (r"Color\(0xFF0284C7\)", "DesignColors.info"),
    (r"const Color\(0xFFDC2626\)", "DesignColors.error"),
    (r"Color\(0xFFDC2626\)", "DesignColors.error"),
    (r"const Color\(0xFFEF4444\)", "DesignColors.error"),
    (r"Color\(0xFFEF4444\)", "DesignColors.error"),
    (r"const Color\(0xFFE53935\)", "DesignColors.error"),
    (r"Color\(0xFFE53935\)", "DesignColors.error"),
    (r"const Color\(0xFFF59E0B\)", "DesignColors.warning"),
    (r"Color\(0xFFF59E0B\)", "DesignColors.warning"),
    (r"const Color\(0xFFD97706\)", "DesignColors.warning"),
    (r"Color\(0xFFD97706\)", "DesignColors.warning"),
    (r"const Color\(0xFF64748B\)", "DesignColors.textTertiary"),
    (r"Color\(0xFF64748B\)", "DesignColors.textTertiary"),
    (r"const Color\(0xFF475569\)", "DesignColors.textSecondary"),
    (r"Color\(0xFF475569\)", "DesignColors.textSecondary"),
    (r"const Color\(0xFF6366F1\)", "DesignColors.secondary"),
    (r"Color\(0xFF6366F1\)", "DesignColors.secondary"),
]

DESIGN_IMPORT = "import '../../../../core/theme/design_tokens.dart';"
ACTION_IMPORT = "import '../../../../core/theme/action_colors.dart';"


def depth_import(prefix: str, file: Path) -> str:
    rel = len(file.relative_to(ROOT.parent).parts) - 1
    dots = "../" * rel
    return prefix.replace("../../../../", dots)


def ensure_import(content: str, file: Path, token: str, import_line: str) -> str:
    if token in content:
        return content
    if import_line.split("'")[1].split("/")[-1] in content:
        return content
    # insert after last import
    lines = content.splitlines(keepends=True)
    last_import = 0
    for i, line in enumerate(lines):
        if line.startswith("import "):
            last_import = i
    lines.insert(last_import + 1, design_import(file) if "design_tokens" in import_line else action_import(file))
    return "".join(lines)


def design_import(file: Path) -> str:
    rel = len(file.relative_to(ROOT.parent).parts) - 1
    return f"import {'../' * rel}core/theme/design_tokens.dart';\n"


def action_import(file: Path) -> str:
    rel = len(file.relative_to(ROOT.parent).parts) - 1
    return f"import {'../' * rel}core/theme/action_colors.dart';\n"


def migrate_file(path: Path) -> bool:
    original = path.read_text(encoding="utf-8")
    content = original
    for pattern, repl in REPLACEMENTS:
        content = re.sub(pattern, repl, content)

    if content == original:
        return False

    if "DesignColors." in content and "design_tokens.dart" not in content:
        content = ensure_import(content, path, "DesignColors.", design_import(path))
    if "ActionColors." in content and "action_colors.dart" not in content:
        content = ensure_import(content, path, "ActionColors.", action_import(path))

    path.write_text(content, encoding="utf-8")
    return True


def main() -> None:
    changed = 0
    for dart in ROOT.rglob("*.dart"):
        if migrate_file(dart):
            changed += 1
            print(f"updated {dart.relative_to(ROOT.parents[1])}")
    print(f"Done. {changed} file(s) updated.")


if __name__ == "__main__":
    main()
