# Chrome Tab Manager (Swift)

A native macOS Swift project for managing and organizing browser tabs.

## Team workflow (current)

This repository currently follows a **staging-first** delivery model:

- `main` = protected integration/release branch
- `staging` = active implementation branch
- Delivery path = `staging` -> Pull Request -> `main`

### Standard flow

1. Update local `main` from `origin/main`.
2. Switch to `staging`.
3. Fast-forward `staging` from `main`.
4. Implement changes on `staging`.
5. Run validation (build/tests).
6. Push `staging` and create/update PR to `main`.
7. Merge when review and required checks are complete.

## Notes for contributors and agents

- Do not develop directly on `main`.
- Keep docs in sync with workflow changes.
- Prefer small, testable changes.

For additional project docs, see the `Docs/` directory.
