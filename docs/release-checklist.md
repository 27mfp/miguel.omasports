# 1.5.1 — Omarchy 4.5 compatibility patch (2026-11-24)

Local target: Omarchy 4.5.0-3 / Qt 6.12.0, 2026-11-06.

- [x] Manifest at 1.5.1; changelog and preference documentation updated.
- [x] `node tests/run-all.mjs --quick --runtime`: 16 suites passed, including 101 model tests, 16 controller regressions, 7 panel policy/state/detail tests, provider fixtures, security checks, manifest validation, process lifecycle and native UI compatibility.
- [x] `node tests/run-all.mjs --full --interactive --runtime`: 20/20 suites passed, including 18 live-provider checks, 12 headless interaction cases, 24 standard visual views and the 2x scaling view.
- [x] Native compatibility uses real, unpatched Omarchy imports, an offscreen platform and a private home. It checks palette resolution, literal markup, F1 conceal/reveal and cold/published crest behavior.
- [x] Private headless interaction suite: 12 cases passed, including sanitized diagnostics IPC, background off with live games and notifications enabled, canceled retries, guarded deferred requests and fresh baseline on resume.
- [x] Visually reviewed 24 standard dark views, 24 empty/onboarding views, 4 light-palette football views, 6 expanded fixture views, MLB at 100%/150%/200% scale, anti-spoiler fixtures/live/F1 standings, the scrolled league-news card and the diagnostics card in both palettes. All captures respect the viewport height limit.
- [x] Baseline updates were reviewed as images before accepting them. Existing goldens were unchanged; the only new baseline is the reviewed 2x MLB fixtures capture. Captures use a fixed palette, private preferences and a cold local crest cache; no live CDN images enter the mock screenshots.
- [x] Final visual comparison: 24/24 standard dark views plus 2x scaling passed (0–0.012% perceptual difference, within tolerance).
- [x] Production/native-fixture QML parsing, JavaScript syntax, Omarchy manifest validation, ruff/mypy (0 issues), qmllint (0 actionable warnings) and `git diff --check` passed.
- [x] Hosted CI on the PR head (`tests` run 45300846199: node-tests, python-checks, qml-syntax).
- [x] Review and merge PR #3 before creating the release/tag.

Review sheets: [dark](screenshots/release-1.5.1-dark.png), [light](screenshots/release-1.5.1-light.png), [expanded and scaled](screenshots/release-1.5.1-extra.png). They use synthetic data, not live match results.

The [larger implementation plan](omarchy-4.5-plan.md) remains follow-up work. The model and workers are still owned by each widget's panel. Service sharing across monitors, lazy panel construction, global job deadlines, cache/persistence migration and complete live-provider/migration acceptance are not certified by this patch. The installed desktop plugins and real preferences were not changed.

Not re-certified visually in this patch: real OS notification toasts, simulated provider-outage banners, true zero-league onboarding (the harness keeps the default league), RTL/localized layouts, and non-MLB 2x scaling. Their logic remains covered by controller/model/security tests; capture them before advertising those states as release-verified.
