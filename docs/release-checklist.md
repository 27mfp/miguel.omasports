# 1.5.1 — Omarchy 4.5 compatibility patch (unreleased)

Local target: Omarchy 4.5.0-3 / Qt 6.12.0, 2026-11-06.

- [x] Manifest at 1.5.1; changelog and preference documentation updated.
- [x] `node tests/run-all.mjs --quick --runtime`: 15 suites passed, including 101 model tests, 16 controller regressions, provider fixtures, security checks, manifest validation, process lifecycle and native UI compatibility.
- [x] Native compatibility uses real, unpatched Omarchy imports, an offscreen platform and a private home. It checks palette resolution, literal markup, F1 conceal/reveal and cold/published crest behavior.
- [x] Private headless interaction suite: 11 cases passed, including background off with live games and notifications enabled, canceled retries, guarded deferred requests and fresh baseline on resume.
- [x] Visually reviewed 24 standard views in each fixed palette, plus three expanded fixture views and MLB at 100%/150% scale. All captures respect the viewport height limit.
- [x] Baseline updates were reviewed as images before accepting them. Captures now use a fixed dark palette by default, private preferences and a cold local crest cache; no live CDN images enter the mock screenshots. Qt 6.12 host borders and explanatory preference text account for further expected differences from the older baselines.
- [x] Final visual comparison: 24/24 standard dark views and 5/5 expanded/scaled variants passed (all 29 at 0% perceptual difference).
- [x] Production/native-fixture QML parsing, JavaScript syntax, Omarchy manifest validation and `git diff --check` passed.
- [ ] Hosted CI on the PR head.
- [ ] Review and merge the PR before creating a release/tag.

Review sheets: [dark](screenshots/release-1.5.1-dark.png), [light](screenshots/release-1.5.1-light.png), [expanded and scaled](screenshots/release-1.5.1-extra.png). They use synthetic data, not live match results.

The [larger implementation plan](omarchy-4.5-plan.md) remains follow-up work. The model and workers are still owned by each widget's panel. Service sharing across monitors, lazy panel construction, global job deadlines, cache/persistence migration and complete live-provider/migration acceptance are not certified by this patch. The installed desktop plugins and real preferences were not changed.
