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

After editing code, re-run the `cp` line and then `omarchy-restart-shell`
(the installed copy is what runs; the checkout is not live-linked).

**The restart is not optional.** The Omarchy shell runs with
`QS_DISABLE_FILE_WATCHER=1`; the journal still prints `Local plugin changed,
reloading: miguel.omasports`, but the panel keeps running the QML it was
started with. `command cp -f` bypasses a `cp -i` alias, which otherwise
silently skips every overwrite when no TTY is attached.

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
