# Changelog

## 1.5.1 — Unreleased

### Fixed

- Resolve Omarchy palette colors through `Commons.Color` on Qt 6.12, including private test-host palette overrides.
- Treat provider names, news and other plugin-owned display text literally; escape notification-body markup.
- Conceal the bar outcome indicator, F1 winners/session results, podiums and recent form while the result is hidden. Explicit per-match reveal remains available; hide the news wire in anti-spoiler mode.
- Honor background updates as the polling switch: with the panel closed and background updates disabled, stop workers, queues and all provider retry timers. Notifications and live games no longer override this preference; reopening establishes a new alert baseline.
- Keep local cache discovery and notification-tool detection alive when canceling network rounds; explicitly stop these local helpers on teardown.
- Keep the translucent F1 live badge text legible in both palettes.
- Load crests only from the helper-published local cache. A cold or failed cache displays a monogram without a direct remote Image request, and cache publication updates the visible crest.

### Release preparation

- Bump the manifest to 1.5.1 and retain the larger Omarchy 4.5 shared-service/UI plan as follow-up work.
- Add behavioral polling/notification regressions and an opt-in native offscreen UI test with real, unpatched Omarchy imports.

## 1.5.0 — 2026-10-10

### Added

- Compact spotlight summary with expandable match details.
- Three-result previews with expansion to all loaded results within the existing ten-result limit.
- Accessible fixture section and expansion controls, contextual keyboard hints, and two-line spotlight team names.
- Controller regression tests, an opt-in offscreen Quickshell lifecycle test, and expanded/multiple-scale visual baselines.

### Fixed

- Sport and standings selectors retaining labels from previous selections; table changes now reset scroll position.
- ESPN games-behind columns displaying points, and score differences using per-game averages instead of totals.
- Live-row accessibility labels respect hidden scores.
- Live-card period scores revealing results while scores are hidden.
- Standings and schedule dropdowns overlapping the line above them.
- F1 favorites showing a raw driver id instead of the driver's name.
- Portuguese races showing a chequered flag instead of Portugal's flag.
- Live cards shortening only one team's name, and F1 races shown as two "teams" with placeholder crests.
- Pending notifications continuing after alerts were disabled or the sport changed.
- ESPN postponed/canceled games appearing as completed results and malformed competitors interrupting scoreboard parsing.
- Inning/period-only updates retaining stale live-card and spotlight data.
- Overdue fixtures hiding the next future kickoff countdown.
- Saved-state reads and own-write echoes overriding explicit panel routes.
- Mock testing restoring canceled requests as loading or replaying notification queues.
- Mock football live fixtures being removed by a wall-clock cutoff despite the frozen preview clock.
- Mixed-sport mock details, incorrect mock standings groups, stale-source screenshot captures, and cropping at different scales.

### Changed

- Standings use spaced, aligned columns, sport-specific legends with matching colours, and explicit playoff-seeding labels.
- Spotlight home/away presentation shares one component for consistent crests, names, records, and form badges.
- Native UI redesign: fixed navigation, a compact sport picker, clearer score hierarchy, flat fixture/table rows, grouped preferences, and light-theme semantic colors.
- Keyboard cursor movement scrolls focused fixtures into view while the header remains fixed.
- UI tests can use a private Quickshell host with temporary preferences and no desktop-bar changes; screenshots crop IPC-reported geometry.
- ESPN requests prioritize today, cache today/live scoreboards for 15 seconds and surrounding dates/standings for five minutes, and reuse successful days when retrying failures.
- Keyboard row navigation follows the filtered rows actually visible on screen.
- Live-card period scores have quarter/period/inning headers and team labels.
- Positive goal and point differences show a "+" sign in every standings table; F1 constructor names fit without truncation.
- The spotlight footer shows kickoff time instead of repeating the league; F1 lists use race wording and onboarding copy mentions drivers.
- F1 tables and the favorite-driver chip drop placeholder monogram crests, since no constructor artwork is available.
- Consistent sentence-case, plain-language copy across settings, empty states, news and keyboard hints; live counts say matches, games or races per sport.
- Settings cards no longer repeat dividers, and the news card aligns with the schedule's section headings.
- Visual tests verify the loaded source, sport, and route, freeze mock time, and restore temporary display controls after testing.
- Installation documentation explains copied versus linked checkouts and host-specific reload behavior.

### Verification

The implementation passed the full local test matrix, including live provider acceptance, offscreen process lifecycle, 24 standard visual views, seven headless interaction cases, and targeted expanded/scaled captures. The redesign also received isolated light/dark palette and 100%/125%/150% scale checks, plus ten IPC/navigation interaction checks. Hosted runtime/visual matrices remain a follow-up.
