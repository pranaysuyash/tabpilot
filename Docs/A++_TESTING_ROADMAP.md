# A++ Testing Roadmap

## Objectives

- Raise confidence and prevent regressions
- Move toward broad unit/integration/performance coverage

## Phase 1 (Weeks 1-4)

- [x] Add benchmark command (`make benchmark`)
- [x] Add coverage-capable test command (`make test-coverage`)
- [x] Add CI coverage artifact upload
- [ ] Add first wave of deterministic unit tests for core managers/stores

## Phase 2 (Weeks 5-8)

- [ ] Add integration tests for scan/close/export flows
- [ ] Add race-condition-focused tests around async state transitions
- [ ] Add baseline flakiness checks

## Phase 3 (Weeks 9-12)

- [ ] Add release-gate thresholds for test pass rate and key coverage areas
- [ ] Add regression suite for top user journeys
