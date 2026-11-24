## Summary

Describe the user-visible change and why it is needed.

## Verification

- [ ] `node tests/run-all.mjs --quick`
- [ ] `omarchy plugin validate .`
- [ ] UI change: visual suite run (`node tests/ui-session.mjs`) and goldens reviewed
- [ ] Security boundary touched: `node tests/security-hardening.mjs`
- [ ] Python touched: `ruff check ...` and `mypy ...`

Commands and results:

```text
paste exact output here
```

## Risk / rollback

What could regress, and how would a maintainer revert or disable it?

## Screenshots (UI changes only)

Attach before/after captures from the headless harness. Do not paste personal
paths, team favourites, tokens, or provider URLs containing credentials.
