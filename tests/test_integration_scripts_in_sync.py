"""Keep the two bundled odysseus_api.py helper scripts identical.

The same scoped-API CLI helper ships in two integration skill bundles:

  integrations/codex/scripts/odysseus_api.py
  integrations/claude/skills/odysseus/scripts/odysseus_api.py

Each copy MUST stay self-contained: the Codex skill installs to
``~/plugins/odysseus/`` and the Claude skill to ``~/.claude/skills/odysseus/``,
so the script has to live inside each skill folder (a symlink would break on
install). That makes a real shared module impractical here. Instead this test
pins them to be byte-identical so the two cannot silently drift -- edit one,
run this test, and it will point at the other until you copy the change over.
"""

import os
import sys
from pathlib import Path

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

ROOT = Path(__file__).resolve().parent.parent

CODEX = ROOT / "integrations" / "codex" / "scripts" / "odysseus_api.py"
CLAUDE = ROOT / "integrations" / "claude" / "skills" / "odysseus" / "scripts" / "odysseus_api.py"


def test_both_helper_scripts_exist():
    assert CODEX.is_file(), f"missing {CODEX}"
    assert CLAUDE.is_file(), f"missing {CLAUDE}"


def test_codex_and_claude_odysseus_api_are_in_sync():
    """The two bundled helpers must be byte-identical to avoid drift."""
    codex = CODEX.read_bytes()
    claude = CLAUDE.read_bytes()
    if codex != claude:
        # Show where they diverge to make the fix obvious.
        import difflib
        diff = "".join(
            difflib.unified_diff(
                codex.decode("utf-8", "replace").splitlines(keepends=True),
                claude.decode("utf-8", "replace").splitlines(keepends=True),
                fromfile=str(CODEX),
                tofile=str(CLAUDE),
                n=2,
            )
        )
        raise AssertionError(
            "integrations/codex/scripts/odysseus_api.py and "
            "integrations/claude/skills/odysseus/scripts/odysseus_api.py differ. "
            "Keep them identical (each skill ships its own self-contained copy):\n" + diff
        )
