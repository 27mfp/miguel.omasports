# Running OmaSports from source

Omarchy bar-widget plugin (Quickshell/QML + a pure-JS data engine). There is
no build step and no virtualenv: the shell loads the QML straight from the
plugin directory, and `secure_io.py` runs on the system `python3`.

## Install the working tree into the live bar

```bash
omarchy plugin validate .
install_dir="$HOME/.config/omarchy/plugins/miguel.omasports"
mkdir -p "$install_dir"
command cp -f -- *.qml *.py SportsModel.js manifest.json icon.svg icon.png "$install_dir/"
omarchy-shell shell rescanPlugins
omarchy plugin enable miguel.omasports --section right   # or left / center
omarchy-restart-shell   # required: see below
```

For a copied installation, re-run the `cp` line after editing code, then
restart the shell to load the updated QML.

Some development installations link the plugin directory to the checkout.
Check with:

```bash
ls -ld "$HOME/.config/omarchy/plugins/miguel.omasports"
readlink -f "$HOME/.config/omarchy/plugins/miguel.omasports"
```

If the plugin directory points to this checkout, skip `mkdir` and `cp`.
Validate the resolved checkout path, rescan plugins, and restart the shell.
The plugin validator rejects a symlink passed as the plugin folder even
when its target validates successfully.

When the shell runs with `QS_DISABLE_FILE_WATCHER=1`, a rescan alone may
leave the panel running its previous QML. Restart the shell after source
updates in that setup. `command cp -f` bypasses an interactive `cp` alias
for copied installations.

Remove with `omarchy plugin remove miguel.omasports`.

## Poke it without opening the panel

```bash
omarchy-shell miguel.omasports getActiveSport
omarchy-shell miguel.omasports sport mlb      # football f1 nba nfl mlb nhl
omarchy-shell miguel.omasports refresh
omarchy-shell miguel.omasports route fixtures # opens the panel on that tab
```

Logs: `journalctl --user -f | grep omasports`.

## Tests

```bash
node tests/sportsmodel.test.mjs      # unit tests (pure JS)
node tests/offline.mjs               # frozen-payload goldens
node tests/live.mjs mlb              # real provider APIs (football|nba|nfl|mlb|nhl|f1|all)
```

CI runs the offline set listed in `.github/workflows/tests.yml`. Visual and
interaction tests use a headless monitor; see DEVELOPMENT.md before running them.

## Gotchas

- **ESPN rejects date ranges.** Since Sept 2026, `scoreboard?dates=YYYYMMDD-YYYYMMDD`
  returns HTTP 400 for every US sport. Fetch one `dates=YYYYMMDD` per day and merge
  (`Model.espnDateList` + `Model.mergeEspnScoreboardPayloads`).
- Probing ESPN by hand: use `curl --compressed` (responses are gzipped). A
  browser-like User-Agent gets an Akamai "Access Denied".
- `Cannot open: .../logos/*.png` warnings on first run are cache misses;
  crests fall back to the remote URL and then to a monogram.
- A one-time `computeStandingsRows is not a function` warning at shell
  startup is pre-existing and harmless.
