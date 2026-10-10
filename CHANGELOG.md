# Changelog

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
- Visual tests verify the loaded source, sport, and route, freeze mock time, and restore temporary display controls after testing.
- Installation documentation explains copied versus linked checkouts and host-specific reload behavior.

### Verification

The implementation passed the full local test matrix, including live provider acceptance, offscreen process lifecycle, 24 standard visual views, seven headless interaction cases, and targeted expanded/scaled captures. The redesign also received isolated light/dark palette and 100%/125%/150% scale checks, plus ten IPC/navigation interaction checks. Hosted runtime/visual matrices remain a follow-up.
