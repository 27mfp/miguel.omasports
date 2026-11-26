# Running OmaSports from source

Omarchy bar-widget plugin (Quickshell/QML + a pure-JS data engine). There is
no build step and no virtualenv: the shell loads the QML straight from the
plugin directory, and `secure_io.py` runs on the system `python3`.

## Update an installation from GitHub

Run `omarchy plugin update miguel.omasports` for a plugin installed with
`omarchy plugin add`. The updater previews available changes and asks for
confirmation. For unattended updates, Omarchy requires `--yes`.
After an update, use the reload check below if the widget was already loaded.

## Install the working tree into the live bar

Use this from the repository root for a copied installation. Check the
destination first if you already have a linked development checkout.

```bash
(
  set -e
  install_dir="$HOME/.config/omarchy/plugins/miguel.omasports"
  if [ -L "$install_dir" ]; then
    echo "Follow the linked checkout instructions below." >&2
    exit 1
  fi
  mkdir -p "$install_dir"
  command cp -f -- *.qml secure_io.py SportsModel.js manifest.json icon.svg icon.png "$install_dir/"
  command cp -Rf -- controllers model "$install_dir/"
  omarchy plugin validate "$install_dir"
  omarchy-shell shell rescanPlugins
)
```

For a new installation, enable it with
`omarchy plugin enable miguel.omasports --section right`. For updates to a
copied installation, repeat the copy and validation steps.

### Linked development checkouts

Some development installations link the plugin directory to the checkout.
Check with:

```bash
ls -ld "$HOME/.config/omarchy/plugins/miguel.omasports"
readlink -f "$HOME/.config/omarchy/plugins/miguel.omasports"
```

Update the checkout at the resolved path using Git, then pass that path to
`omarchy plugin validate` and run `omarchy-shell shell rescanPlugins`.
Omarchy 4.5 rejects the symlink path during validation, so its plugin
updater can roll back an otherwise valid update of a linked checkout.

### Check the loaded version

For an enabled widget, run `omarchy-shell miguel.omasports getDiagnostics`
and check the `plugin:` line. The 1.5.0 widget does not have this IPC method.
In an isolated 1.5.0 to 1.5.1 upgrade on Omarchy 4.5, rescanning kept the old
QML in memory. If the shell still serves the old widget after a rescan, run
`omarchy-restart-shell` when you can interrupt the bar briefly, then check
the loaded version again. The visual suite also checks a source revision
before capturing.
Rescanning can close plugin panels, and restarting briefly redraws the bar.

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
- Crests use only the validated local cache. A cold cache shows a monogram
  until the helper publishes the image; no remote Image fallback is used.
- A one-time `computeStandingsRows is not a function` warning at shell
  startup is pre-existing and harmless.
