# Changelog

## 1.5.0 (proposed)

### Added

- Compact spotlight summary with expandable match details.
- Three-result previews with expansion to all loaded results within the existing ten-result limit.
- Accessible fixture section and expansion controls, contextual keyboard hints, and two-line spotlight team names.
- Controller regression tests, an opt-in offscreen Quickshell lifecycle test, and expanded/multiple-scale visual baselines.

### Fixed

- Pending notifications continuing after alerts were disabled or the sport changed.
- ESPN postponed/canceled games appearing as completed results and malformed competitors interrupting scoreboard parsing.
- Inning/period-only updates retaining stale live-card and spotlight data.
- Overdue fixtures hiding the next future kickoff countdown.
- Saved-state reads and own-write echoes overriding explicit panel routes.
- Mock testing restoring canceled requests as loading or replaying notification queues.
- Mixed-sport mock details, incorrect mock standings groups, stale-source screenshot captures, and cropping at different scales.

### Changed

- ESPN requests prioritize today, cache today/live scoreboards for 15 seconds and surrounding dates/standings for five minutes, and reuse successful days when retrying failures.
- Keyboard row navigation follows the filtered rows actually visible on screen.
- Visual tests verify the loaded source, sport, and route, freeze mock time, and restore temporary display controls after testing.
- Installation documentation explains copied versus linked checkouts and host-specific reload behavior.

### Verification

The implementation passed the full local test matrix, including live provider acceptance, offscreen process lifecycle, 24 standard visual views, seven headless interaction cases, and targeted expanded/scaled captures. Full light/dark-theme and hosted runtime/visual matrices remain follow-ups.

This entry describes the proposed release. A version bump and PR do not create a release tag or publish a GitHub Release.
