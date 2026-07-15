"""Pin the vault master-password handling so it never regresses into argv.

`routes.vault_routes._run_bw` launches the Bitwarden CLI with
``asyncio.create_subprocess_exec(bw_path, *args)`` — every element of ``args``
becomes a process argument, which is world-readable through ``ps`` /
``/proc/<pid>/cmdline``. The master password therefore must be handed to ``bw``
out-of-band (stdin or ``--passwordenv BW_PASSWORD``), and never as a positional
argv element.

The /unlock route previously did ``_run_bw(["unlock", req.master_password,
"--raw"])`` — leaking the Bitwarden master password (which decrypts the whole
vault) to any local user for the lifetime of the unlock subprocess.
"""

import os
import json
import re
import sys
import types
from unittest.mock import MagicMock

import pytest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# Importing routes.vault_routes pulls in core.middleware → core/__init__ →
# session_manager, which explodes under the conftest stubs. Stub the heavy
# imports the module needs so we can reach the self-contained _run_bw helper.
if "core.database" not in sys.modules:
    _db = types.ModuleType("core.database")
    for _n in ("SessionLocal", "ChatMessage", "Session", "Document"):
        setattr(_db, _n, MagicMock())
    sys.modules["core.database"] = _db
if "core.middleware" not in sys.modules:
    _mw = types.ModuleType("core.middleware")
    _mw.require_admin = MagicMock()
    sys.modules["core.middleware"] = _mw
if "core.platform_compat" not in sys.modules:
    _pc = types.ModuleType("core.platform_compat")
    _pc.IS_WINDOWS = False
    _pc.safe_chmod = MagicMock()
    _pc.which_tool = MagicMock(return_value="bw")
    sys.modules["core.platform_compat"] = _pc

import routes.vault_routes as vr  # noqa: E402


class _FakeProc:
    def __init__(self, stdout=b"session-key", stderr=b"", rc=0):
        self._out, self._err, self.returncode = stdout, stderr, rc

    async def communicate(self, input=None):
        return self._out, self._err


def _patch_exec(monkeypatch):
    """Capture the argv + env handed to create_subprocess_exec."""
    captured = {}

    async def _fake_exec(*argv, env=None, **kwargs):
        captured["argv"] = list(argv)
        captured["env"] = env or {}
        return _FakeProc()

    monkeypatch.setattr(vr, "_find_bw", lambda: "bw")
    monkeypatch.setattr(vr.asyncio, "create_subprocess_exec", _fake_exec)
    return captured


@pytest.mark.asyncio
async def test_run_bw_never_accepts_password_via_env(monkeypatch):
    """_run_bw must not support a password-via-env path at all -- the child
    environment is readable via /proc/<pid>/environ on Linux. The master
    password is passed on stdin only. Calling with a legacy `bw_password`
    kwarg must now raise (the path was removed), and env must never contain it.
    """
    captured = _patch_exec(monkeypatch)
    import inspect
    params = inspect.signature(vr._run_bw).parameters
    assert "bw_password" not in params, "_run_bw must not accept bw_password= (removed: /proc environ leak vector)"
    # No way to pass a password env via _run_bw anymore; prove the env stays clean.
    await vr._run_bw(["lock"])
    assert "BW_PASSWORD" not in captured["env"]


def test_unlock_handler_feeds_password_on_stdin_not_argv():
    """Source-level guard: the /unlock route must feed the master password via
    stdin, never as a bare positional argv element."""
    src = vr.__file__
    with open(src, encoding="utf-8") as fh:
        text = fh.read()
    # The old, vulnerable call shape must be gone.
    assert 'req.master_password, "--raw"' not in text
    assert "[\"unlock\", req.master_password" not in text
    # And the safer stdin shape must be present.
    assert "[\"unlock\", \"--raw\"]" in text
    assert re.search(r'input_text\s*=\s*req\.master_password\s*\+\s*"\\n"', text)


def test_tool_vault_unlock_feeds_password_on_stdin_not_argv():
    text = open("src/tool_implementations.py", encoding="utf-8").read()

    assert '["unlock", master_password, "--raw"]' not in text
    assert '_run_bw(["unlock", master_password' not in text
    assert re.search(r'input_text\s*=\s*master_password\s*\+\s*"\\n"', text)


def test_load_config_ignores_non_object_json(tmp_path, monkeypatch):
    vault_file = tmp_path / "vault.json"
    vault_file.write_text(json.dumps(["not", "a", "config", "object"]), encoding="utf-8")
    monkeypatch.setattr(vr, "VAULT_FILE", vault_file)

    assert vr._load_config() == {}
