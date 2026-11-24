# Contributing to OmaSports

OmaSports is an Omarchy bar plugin. Keep the plugin contract stable and verify
UI changes on a headless output rather than the live desktop.

## Before you start

- Read [DEVELOPMENT.md](DEVELOPMENT.md) for the architecture map, IPC contract,
  polling floors, and test playbook.
- Runtime dependencies are intentionally limited to `/usr/bin/python3`,
  `xdg-open`, and optional `notify-send`. Do not add npm or PyPI runtime
  dependencies.
- Never weaken URL allowlists, path validation, byte ceilings, process-group
  cleanup, or markup escaping in `secure_io.py`, `NetworkProcess.qml`,
  `SecureProcess.qml`, or the model text helpers.

## Quality gate

```bash
node tests/run-all.mjs --quick
omarchy plugin validate .
```

For UI work, use the private host and review candidate captures before updating
any baseline:

```bash
node tests/ui-session.mjs -- node tests/visual.mjs --sport=football --tab=all --capture-only
node tests/ui-session.mjs -- node tests/interaction.mjs
```

Python checks are optional locally and run in CI:

```bash
uvx ruff check secure_io.py tests/security-helper.py tests/diff.py tests/crop.py
uvx mypy secure_io.py tests/security-helper.py tests/diff.py tests/crop.py
```

## Fixtures

Large provider payloads are stored gzip-compressed and read through
`tests/fixture-io.mjs`. Refresh them only when intentionally updating provider
schemas:

```bash
node tests/capture-fixtures.mjs
node tests/offline.mjs
```

Visual goldens are reviewed screenshots, not generated truth. Capture at the
requested scale, inspect the candidate, then update the matching baseline.

## Commits and pull requests

Keep changes focused. Describe the user-visible effect, the exact commands you
ran, and any security or visual risk. Use the pull request template.
