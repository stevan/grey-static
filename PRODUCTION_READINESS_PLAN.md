# Production Readiness Plan - grey::static

**Date:** 2025-12-09
**Current Status:** Not Production Ready (6.5/10)
**Target:** Production Ready for Non-Critical Use (8.5/10)

---

## Overview

This document outlines a phased approach to making grey::static production-ready. Issues are organized by priority and estimated effort.

**Total Estimated Effort:** 2-3 weeks (part-time) or 1 week (full-time)

---

## Phase 1: Blocking Issues (MUST FIX)

**Goal:** Enable installation and distribution
**Estimated Effort:** 2-3 days
**Target Score:** 7/10

### 1.1 Create Distribution Metadata

**File:** `Makefile.PL` or `cpanfile`

**Tasks:**
- [ ] Choose build system (ExtUtils::MakeMaker or Module::Build::Tiny)
- [ ] Create `Makefile.PL` with:
  - Perl version requirement (v5.42+)
  - Dependencies: Path::Tiny, Term::ReadKey, Time::HiRes, B
  - Author information
  - License (choose: Artistic 2.0, MIT, or other)
  - Abstract and description
- [ ] Add `MANIFEST` file listing all distributable files
- [ ] Add `MANIFEST.SKIP` for excluding development files
- [ ] Test installation: `perl Makefile.PL && make && make test`
- [ ] Verify module can be installed locally: `make install`

**Deliverable:** Installable distribution via CPAN toolchain

---

### 1.2 Complete README.md

**File:** `README.md`

**Tasks:**
- [ ] Replace placeholder content with comprehensive README
- [ ] Add sections:
  - **Name and description** - One-line summary
  - **Features** - Bullet list of all features (diagnostics, functional, stream, etc.)
  - **Requirements** - Perl v5.42+, list CPAN dependencies
  - **Installation** - Instructions for cpanm, cpan, and manual install
  - **Quick Start** - Simple usage example showing 2-3 features
  - **Features Overview** - Brief description of each feature with links to docs
  - **Testing** - How to run tests (`prove -lr t/`)
  - **Documentation** - Link to POD docs
  - **Examples** - Link to examples/ directory
  - **Contributing** - Basic guidelines
  - **License** - License information
  - **Author** - Author/maintainer information
- [ ] Validate all code examples work
- [ ] Ensure links are correct

**Deliverable:** Professional, informative README

---

### 1.3 Fix or Remove Stream::Operation::Recurse

**Files:** `lib/grey/static/stream/Stream/Operation/Recurse.pm`, `t/grey/static/02-stream/010-recurse.t`

**Tasks:**
- [ ] Review implementation issues documented in test file
- [ ] Check p7 reference implementation: `/Users/stevan/Projects/perl/p7/lib/org/p7/util/stream/Stream/Operation/Recurse.pm`
- [ ] Attempt fix based on p7 implementation
- [ ] If fixable:
  - [ ] Implement fix
  - [ ] Enable and expand tests in `t/grey/static/02-stream/010-recurse.t`
  - [ ] Verify all test cases pass
- [ ] If not easily fixable:
  - [ ] Remove `Recurse.pm` from codebase
  - [ ] Remove from `lib/grey/static/stream.pm` loader
  - [ ] Remove `Stream->recurse()` method from `lib/grey/static/stream/Stream.pm`
  - [ ] Delete test file
  - [ ] Document as future feature in CHANGELOG
- [ ] Decision point: Fix or remove by 2025-12-12

**Deliverable:** No known broken code in distribution

---

### 1.4 Create CHANGELOG.md

**File:** `CHANGELOG.md`

**Tasks:**
- [ ] Create CHANGELOG following Keep a Changelog format
- [ ] Document version 0.01 (initial release):
  - **Added** - List all implemented features
  - **Known Issues** - Document any remaining issues
  - **Limitations** - Document design limitations (no cancellation, single-threaded, etc.)
- [ ] Add placeholder for 0.02
- [ ] Document differences from p7 (breaking changes, new features)

**Template:**
```markdown
# Changelog

All notable changes to grey::static will be documented in this file.

## [Unreleased]

## [0.01] - 2025-12-XX

### Added
- Feature loader with sub-feature support
- diagnostics: Rust-style error/warning display
- functional: Function, BiFunction, Predicate, Consumer, BiConsumer, Supplier, Comparator
- logging: Debug logging with colorization
- stream: Lazy stream processing API
- io::stream: File and directory streaming
- concurrency::reactive: Reactive Flow API with backpressure
- concurrency::util: Executor and Promise
- datatypes::ml: Tensor, Scalar, Vector, Matrix
- datatypes::util: Option and Result
- tty::ansi: Terminal control (cursor, colors, mouse)
- time::stream: Time-based streams
- time::wheel: Hierarchical timing wheel
- mop: Meta-Object Protocol

### Known Issues
- Source file cache has no size limits (potential memory leak)
- Not thread-safe (single-threaded use only)
- No cancellation support for Promises

### Limitations
- Requires Perl v5.42+ (uses class feature)
```

**Deliverable:** Complete version history

---

## Phase 2: High Priority (SHOULD FIX)

**Goal:** Production hardening
**Estimated Effort:** 1 week
**Target Score:** 8.5/10

### 2.1 Add Resource Management

**Files:** `lib/grey/static/source.pm`, `lib/grey/static/time/wheel/Timer/Wheel.pm`

**Tasks:**

**Source Cache Management:**
- [ ] Add configurable cache size limit (`$MAX_CACHE_SIZE`, default 100 files)
- [ ] Implement LRU eviction when cache is full
- [ ] Add `clear_cache()` function to manually clear
- [ ] Track cache hits/misses for diagnostics
- [ ] Document cache behavior in POD
- [ ] Add tests for cache eviction

**Timer::Wheel Limits:**
- [ ] Add configurable max timer count (`$MAX_TIMERS`, default 10,000)
- [ ] Throw error when limit exceeded
- [ ] Add `timer_count()` method
- [ ] Document limit in POD
- [ ] Add tests for limit enforcement

**IO::Stream Cleanup:**
- [ ] Review file handle management
- [ ] Ensure all file handles are properly closed
- [ ] Add explicit cleanup documentation
- [ ] Consider DEMOLISH blocks for cleanup
- [ ] Add tests for resource cleanup

**Deliverable:** Bounded resource usage

---

### 2.2 Improve Error Messages

**Files:** Multiple (all modules with `die` statements)

**Tasks:**
- [ ] Audit all `die()` calls in codebase
- [ ] Add context to each error:
  - What operation failed
  - What inputs were provided
  - What was expected
  - Hint for fixing
- [ ] Examples to fix:
  - `lib/grey/static/datatypes/util/Option.pm:14` - Add context about None value
  - `lib/grey/static/stream/Stream/Match/Builder.pm` - Add builder state info
  - All parameter validation errors
- [ ] Consider creating exception classes:
  - `grey::static::Error`
  - `grey::static::Error::InvalidArgument`
  - `grey::static::Error::ResourceLimit`
  - `grey::static::Error::State`
- [ ] Update tests to verify error messages
- [ ] Document error handling approach in README

**Deliverable:** Helpful, actionable error messages

---

### 2.3 Document Thread Safety

**Files:** Multiple POD sections, README.md

**Tasks:**
- [ ] Add thread safety section to main module POD
- [ ] Explicitly state: "Not thread-safe - designed for single-threaded use"
- [ ] Document shared state:
  - Source file cache (module-level)
  - Logging state variables
  - Signal handlers (__DIE__, __WARN__)
- [ ] Provide workarounds if needed:
  - Per-thread isolation approaches
  - fork-safe usage patterns
- [ ] Add to README under "Limitations"
- [ ] Consider adding runtime detection of threads and warn

**Deliverable:** Clear thread safety expectations

---

### 2.4 Complete TODO Items

**Files:** `lib/grey/static/concurrency/util/Executor.pm`

**Tasks:**
- [ ] Review `Executor.pm:100` - TODO in `diag()` method
- [ ] Determine what diagnostic output is useful:
  - Pending callback count
  - Next tick time
  - Callback queue state
  - Executor run state
- [ ] Either implement diagnostic output or remove method entirely
- [ ] Remove TODO comment
- [ ] Add tests for `diag()` if implemented
- [ ] Search codebase for any other TODO comments: `grep -r "TODO" lib/`
- [ ] Address or document each TODO found

**Deliverable:** No TODO comments in production code

---

### 2.5 Add Input Validation

**Files:** Multiple (constructors and method parameters)

**Tasks:**
- [ ] Audit all constructors for validation needs
- [ ] Add validation for:
  - Type checking (use `builtin::blessed`, `builtin::reftype`)
  - Range checking (numeric bounds)
  - Null/undef checking where not allowed
  - Collection size limits
- [ ] Priority modules to validate:
  - Stream sources (check array refs, code refs)
  - Functional classes (check callable parameters)
  - Tensor/Matrix (check dimensions, bounds)
  - Promise (check executor type)
- [ ] Throw descriptive errors on validation failure
- [ ] Add tests for invalid inputs
- [ ] Document validation behavior in POD

**Deliverable:** Robust parameter validation

---

## Phase 3: Medium Priority (NICE TO HAVE)

**Goal:** Professional polish
**Estimated Effort:** 1 week
**Target Score:** 9/10

### 3.1 Add Configuration API

**File:** `lib/grey/static/diagnostics.pm`, new `lib/grey/static/diagnostics/Config.pm`

**Tasks:**
- [ ] Create `grey::static::diagnostics::Config` class
- [ ] Support configuration options:
  - `no_color` (boolean)
  - `no_backtrace` (boolean)
  - `no_syntax_highlight` (boolean)
  - `context_lines` (integer, default 2)
  - `max_backtrace_depth` (integer, default unlimited)
- [ ] Provide API:
  - `Config->new(%options)` - Create config
  - `Config->apply()` - Apply to diagnostics
  - `Config->restore()` - Restore previous config
- [ ] Support lexical scoping:
  ```perl
  {
      my $config = grey::static::diagnostics::Config->new(no_color => 1);
      $config->apply();
      # colored output disabled in this scope
  }
  # restored here
  ```
- [ ] Maintain backward compatibility with package globals
- [ ] Document new API in POD
- [ ] Add tests for configuration
- [ ] Update examples to show configuration

**Deliverable:** Programmatic diagnostics configuration

---

### 3.2 Performance Documentation

**Files:** POD sections, new `docs/PERFORMANCE.md`

**Tasks:**
- [ ] Document time complexity for each operation:
  - Stream operations (map: O(n), filter: O(n), etc.)
  - Tensor operations (broadcast: O(n), matmul: O(n³), etc.)
  - Timer::Wheel operations (insert: O(1), tick: O(1), etc.)
- [ ] Document space complexity and memory usage:
  - Source cache memory overhead
  - Stream intermediate objects
  - Tensor memory layout
- [ ] Provide performance guidance:
  - Best practices for large datasets
  - When to use buffered streams
  - Memory vs. speed tradeoffs
- [ ] Add benchmarks:
  - Create `bench/` directory
  - Benchmark critical operations
  - Compare against naive implementations
- [ ] Document performance testing approach
- [ ] Add to README under "Performance"

**Deliverable:** Performance characteristics documented

---

### 3.3 Examples as Tests

**Files:** `t/99-examples.t` (new), examples/*

**Tasks:**
- [ ] Create `t/99-examples.t`
- [ ] Load and execute each example script
- [ ] Capture output and verify expected results
- [ ] Handle examples that require user input (skip or mock)
- [ ] Ensure examples stay current with code changes
- [ ] Add CI check for example validity
- [ ] Document example testing in CONTRIBUTING

**Example test structure:**
```perl
use Test2::V0;
use File::Temp qw(tempdir);

subtest 'demo.pl runs without errors' => sub {
    my $output = `perl examples/demo.pl 2>&1`;
    is $?, 0, 'demo.pl exits successfully';
    like $output, qr/expected output pattern/, 'output contains expected content';
};

done_testing;
```

**Deliverable:** Validated examples

---

### 3.4 Security Hardening

**Files:** `lib/grey/static/source.pm`, documentation

**Tasks:**
- [ ] Add path validation in `source.pm`:
  - Resolve symlinks
  - Check for directory traversal (../)
  - Validate path is within project root
  - Add `$SAFE_MODE` flag to enable restrictions
- [ ] Document security model:
  - Source file access behavior
  - Potential risks (arbitrary file reading)
  - Recommended usage patterns
  - Safe mode documentation
- [ ] Add security section to README
- [ ] Consider creating security policy (SECURITY.md)
- [ ] Add tests for path validation
- [ ] Review for other security concerns:
  - Eval usage (currently safe)
  - System command execution (none found)
  - Untrusted input handling

**Deliverable:** Security-conscious implementation and documentation

---

### 3.5 CONTRIBUTING Guide

**File:** `CONTRIBUTING.md` (new)

**Tasks:**
- [ ] Create CONTRIBUTING.md with sections:
  - **Getting Started** - Clone, install deps, run tests
  - **Development Workflow** - Branch naming, commit messages
  - **Testing** - How to write tests, run test suite
  - **Code Style** - Formatting conventions, naming patterns
  - **Porting from p7** - Guidelines from CLAUDE.md
  - **Feature Addition** - How to add new features
  - **Submitting Changes** - Pull request process
  - **Release Process** - Version bumping, changelog updates
- [ ] Include code style guidelines:
  - Use v5.42 class feature
  - Field naming conventions
  - POD documentation requirements
  - Test coverage expectations
- [ ] Document testing requirements:
  - All new code must have tests
  - Edge cases and error conditions
  - Integration tests for features
- [ ] Add to README (link to CONTRIBUTING)

**Deliverable:** Contributor documentation

---

## Phase 4: Advanced Improvements (FUTURE)

**Goal:** Mission-critical readiness
**Estimated Effort:** 2-3 weeks
**Target Score:** 9.5/10

### 4.1 Stress and Performance Testing

**Files:** `t/stress/` (new directory)

**Tasks:**
- [ ] Create stress test suite:
  - Large dataset processing (1M+ elements)
  - Long-running operations (hours)
  - High memory pressure scenarios
  - Deep recursion/nesting
  - Many concurrent streams
- [ ] Add memory leak detection:
  - Use Test::Memory::Cycle
  - Monitor RSS growth over time
  - Verify cache eviction works
- [ ] Performance regression tests:
  - Benchmark key operations
  - Track performance over versions
  - Alert on significant degradation
- [ ] Document stress test results
- [ ] Add to CI (separate slow test job)

**Deliverable:** Confidence in production scale

---

### 4.2 Thread Safety Implementation

**Files:** Multiple (if implementing thread safety)

**Tasks:**
- [ ] **Decision Point:** Is thread safety required?
  - If NO: Mark Phase 4.2 as "Not Applicable"
  - If YES: Proceed with tasks below
- [ ] Add thread-safe source cache:
  - Use Hash::SharedMem or similar
  - Add locking around cache operations
  - Per-thread cache alternative
- [ ] Make logging thread-safe:
  - Thread-local state variables
  - Synchronized output
- [ ] Document thread-safe usage
- [ ] Add thread safety tests:
  - Concurrent cache access
  - Concurrent logging
  - Race condition detection
- [ ] Update README and POD

**Deliverable:** Thread-safe implementation (if needed)

---

### 4.3 Advanced Error Recovery

**Files:** New error handling infrastructure

**Tasks:**
- [ ] Design error recovery API:
  - Retry mechanisms
  - Fallback handlers
  - Error callbacks
- [ ] Add to Stream operations:
  - `->recover(sub { ... })` - Fallback on error
  - `->retry($n)` - Retry operation n times
  - `->on_error(sub { ... })` - Error callback
- [ ] Add to Promise:
  - Timeout support
  - Cancellation tokens
  - Error recovery chains
- [ ] Add to Flow operations:
  - Error stream handling
  - Backpressure on errors
- [ ] Document error recovery patterns
- [ ] Add comprehensive tests

**Deliverable:** Robust error handling options

---

### 4.4 Profiling and Optimization

**Files:** Multiple (optimization targets)

**Tasks:**
- [ ] Profile hot paths:
  - Use Devel::NYTProf
  - Identify bottlenecks
  - Measure memory allocation
- [ ] Optimize identified bottlenecks:
  - Object creation overhead
  - Method dispatch costs
  - Cache misses
- [ ] Consider XS for critical paths:
  - Tensor operations
  - Stream operations
  - Source file parsing
- [ ] Document optimization decisions
- [ ] Add performance tests
- [ ] Benchmark improvements

**Deliverable:** Optimized critical paths

---

## Success Criteria

### Phase 1 Complete (Minimum Viable Release)
- [ ] Can be installed via `cpanm grey::static`
- [ ] README provides clear usage instructions
- [ ] No known broken features
- [ ] CHANGELOG documents v0.01

### Phase 2 Complete (Production Ready)
- [ ] Resource usage is bounded
- [ ] Error messages are helpful
- [ ] Thread safety is documented
- [ ] No TODO comments remain

### Phase 3 Complete (Professional Quality)
- [ ] Configuration API available
- [ ] Performance characteristics documented
- [ ] Examples are validated
- [ ] Security model documented

### Phase 4 Complete (Mission Critical)
- [ ] Stress tested at scale
- [ ] Thread-safe (if required)
- [ ] Error recovery mechanisms
- [ ] Optimized performance

---

## Timeline

**Conservative Estimate (part-time):**
- Phase 1: Week 1-2 (blocking issues)
- Phase 2: Week 3-4 (hardening)
- Phase 3: Week 5-6 (polish)
- Phase 4: Week 7-9 (advanced)

**Aggressive Estimate (full-time):**
- Phase 1: Days 1-3 (blocking)
- Phase 2: Days 4-8 (hardening)
- Phase 3: Days 9-13 (polish)
- Phase 4: Days 14-28 (advanced)

---

## Risk Assessment

### High Risk Items
1. **Stream::Operation::Recurse** - May require significant debugging; fallback is removal
2. **Thread Safety (Phase 4)** - Major architectural change if implemented; may not be feasible

### Medium Risk Items
1. **Resource Management** - Cache eviction complexity; may impact performance
2. **Error Recovery (Phase 4)** - API design is complex; may introduce breaking changes

### Low Risk Items
1. **Documentation** - Time-consuming but straightforward
2. **Validation** - Well-understood patterns, low complexity

---

## Notes

- This plan assumes single maintainer working part-time
- Phases can be parallelized if multiple contributors
- Phase 4 is optional for most use cases
- Focus on Phase 1-2 for first production release
- Version 0.01 targets completion of Phase 1-2
- Version 0.02+ can include Phase 3-4 improvements

---

## Next Steps

1. Review this plan and adjust priorities
2. Set target completion date for Phase 1
3. Begin with Task 1.1 (Distribution Metadata)
4. Update this document as work progresses
5. Check off completed tasks
6. Celebrate milestones!
