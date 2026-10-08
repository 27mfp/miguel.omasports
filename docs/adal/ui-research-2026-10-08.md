# UI research and implementation notes

Date: 2026-10-08
POC: Miguel
TL;DR: Keep Omarchy theme integration, improve keyboard navigation and dense-data freshness, and preserve separate loading/empty/error states. Avoid a wholesale visual redesign before comparing safe headless captures.

## References

- [Omarchy Notification Center](https://github.com/jankeesvw/omarchy-notification-center): grouped cards, date headings, search, explicit DND controls and bounded history. The research pass reported the strongest marketplace adoption among the sampled plugins; those marketplace counts are point-in-time indicators, not GitHub star counts or security guarantees.
- [Omarchy Agenda](https://github.com/danitrrga/omarchy-agenda): current-event emphasis, upcoming context, keyboard navigation, warning states and synthetic screenshot data. A recent small project; do not treat it as an established community standard.
- [Omarchy Asana](https://github.com/tomtorggler/omarchy-asana): grouped lists, foldable sections and documented keyboard controls. Useful for long fixture lists, with limited adoption evidence.
- [CPU/Network](https://github.com/jcnecio/cpu-net): compact bar summary and richer panel, explicit refresh controls and configurable polling. Current popularity/activity was not independently established.
- [Lifetime](https://github.com/murtazatunio/lifetime): theme-aware views, keyboard shortcuts, synthetic screenshot and offscreen-test treatment. A small project, not evidence of a widespread convention.
- [Official shell/plugin reference](https://github.com/omacom/omarchy/blob/quattro/docs/omarchy-shell.md) and [bar documentation](https://github.com/omacom/omarchy/blob/quattro/shell/plugins/bar/README.md): shared theme tokens, widget anchoring and explicit selected/hover/focus states.

## Implemented direction

- Keyboard-operable, named fixture subsection controls with a visible selected-focus outline.
- Keyboard fixture indices follow filtered, visible rows, including the six-row upcoming limit; hidden results or news do not leave invisible keyboard stops.
- Upcoming expansion is an accessible action and part of the custom navigation model.
- Live rows and favorite spotlight resolve fresh match objects by ID separately from repeater identity, allowing linescore-only updates without replacing the whole list.
- Future-only kickoff selection with clock rollover; exceptional ESPN statuses avoid misleading final scores.
- Today-first ESPN fetching, short freshness for live/today and longer TTLs for surrounding days/standings; failed-day retries retain successful responses.

## Further design ideas

1. Add a compact sticky live summary only if it improves scanning without duplicating the spotlight and live tab.
2. Consider collapsible recent-result groups, with persistent counts and keyboard controls. Keep live matches visible by default.
3. Add small contextual key hints for subsection arrows, activation, score reveal and expansion.
4. Compare low/high-density states in light and dark themes and at different display scales before changing typography or surface contrast.
5. Expand synthetic UI scenarios for partial provider failures, delayed/postponed games and inning-only updates.

These are suggestions informed by other plugins, not claims that their implementation is necessarily better. Native QML validation uses Quickshell/headless tooling rather than a web browser.
