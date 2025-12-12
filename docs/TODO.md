# grey::static - Active TODO List

Last Updated: 2025-12-12

> **Note:** For historical context and completed work, see `docs/archived/TODO-2025-12-10.md` and `docs/archived/PRODUCTION_READINESS_PLAN.md`

---

## Documentation

### Flow POD Enhancement
**Files:**
- `lib/grey/static/concurrency/reactive/Flow.pm`
- `lib/grey/static/concurrency/reactive/Flow/Publisher.pm`
- `lib/grey/static/concurrency/reactive/Flow/Subscriber.pm`
- `lib/grey/static/concurrency/reactive/Flow/Subscription.pm`
- `lib/grey/static/concurrency/reactive/Flow/Operation.pm`

**Tasks:**
- [ ] Document backpressure mechanism
- [ ] Explain executor chaining
- [ ] Add comprehensive examples
- [ ] Document when to use Flow vs Stream
- [ ] Performance guidance (request_size optimization)

### Promise POD Enhancement
**File:** `lib/grey/static/concurrency/util/Promise.pm`

**Tasks:**
- [ ] Document all Promise methods
- [ ] Add chaining examples
- [ ] Document error handling pattern (then(onSuccess, onError))
- [ ] Include integration examples with ScheduledExecutor

---

## Production Hardening

### Resource Management
**Files:** `lib/grey/static/source.pm`

**Source Cache Management:**
- [ ] Add configurable cache size limit (`$MAX_CACHE_SIZE`, default 100 files)
- [ ] Implement LRU eviction when cache is full
- [ ] Add `clear_cache()` function to manually clear
- [ ] Track cache hits/misses for diagnostics
- [ ] Document cache behavior in POD
- [ ] Add tests for cache eviction

### Improve Error Messages
**Files:** Multiple (all modules with `die` statements)

**Tasks:**
- [ ] Audit all `die()` calls in codebase
- [ ] Add context to each error (what failed, inputs, expected, fix hint)
- [ ] Consider creating exception classes (grey::static::Error::*)
- [ ] Update tests to verify error messages

### Document Thread Safety
**Files:** Multiple POD sections, README.md

**Tasks:**
- [ ] Add thread safety section to main module POD
- [ ] Explicitly state: "Not thread-safe - designed for single-threaded use"
- [ ] Document shared state (source cache, logging, signal handlers)
- [ ] Add to README under "Limitations"

### Input Validation
**Files:** Multiple (constructors and method parameters)

**Tasks:**
- [ ] Audit all constructors for validation needs
- [ ] Add validation for types, ranges, null/undef checking
- [ ] Priority modules: Stream sources, Functional classes, Tensor/Matrix, Promise
- [ ] Throw descriptive errors on validation failure
- [ ] Add tests for invalid inputs

---

## Integration Plans (Active)

### Actor System Integration (Yakt)
**Plan Document:** `docs/yakt-integration-plan.md`
**Feature:** `concurrency::actor`

**Phases:**
- [ ] Phase 1: Foundation Alignment (Timer wrapper, ScheduledExecutor integration)
- [ ] Phase 2: Core Actor Port (Actor, Props, Ref, Context, Behavior, Message)
- [ ] Phase 3: System Infrastructure (Mailbox, Signals, Supervisors, ActorSystem)
- [ ] Phase 4: IO Integration (Selectors for async IO)
- [ ] Phase 5: Bridge Classes (Actor-Flow, Actor-Promise interop)
- [ ] Phase 6: Documentation & Examples

### Terminal Graphics (tty::graphics)
**Plan Document:** `docs/tty-graphics-integration-plan.md`
**Status:** Phases 1-3 complete, Phases 4-5 deferred

**Deferred Work:**
- [ ] Phase 4: Advanced Features (layout system, widgets, text rendering, animation utilities)
- [ ] Phase 5: Examples and Documentation (port Philo examples, integration examples)

---

## Future Enhancements (Low Priority)

### Performance Documentation
- [ ] Document time complexity for each operation
- [ ] Document space complexity and memory usage
- [ ] Provide performance guidance for large datasets
- [ ] Add benchmarks in `bench/` directory

### Configuration API
**File:** `lib/grey/static/diagnostics.pm`

- [ ] Create `grey::static::diagnostics::Config` class
- [ ] Support programmatic configuration (no_color, no_backtrace, context_lines, etc.)
- [ ] Support lexical scoping for configuration
- [ ] Maintain backward compatibility with package globals

### Examples as Tests
**File:** `t/99-examples.t` (new)

- [ ] Create test that loads and executes each example script
- [ ] Capture output and verify expected results
- [ ] Ensure examples stay current with code changes

### CONTRIBUTING Guide
**File:** `CONTRIBUTING.md` (new)

- [ ] Getting Started section
- [ ] Development Workflow
- [ ] Testing requirements
- [ ] Code Style guidelines
- [ ] Porting from p7 guidelines (from CLAUDE.md)

---

## Not Planned

These items were considered and explicitly decided against:

- **Flow + ScheduledExecutor integration** - Design mismatch, keep separate
- **Hierarchical Timer::Wheel** - Replaced with simpler queue approach
- **Flow Time Operations** - Stream already has time operations
- **Thread-based parallelism** - Stay cooperative single-threaded

---

## Quick Reference

| Category | Priority | Effort |
|----------|----------|--------|
| Documentation (POD) | Medium | Low |
| Production Hardening | High | Medium |
| Actor Integration | High | High |
| TTY Graphics Phase 4-5 | Low | Medium |
| Future Enhancements | Low | Varies |
