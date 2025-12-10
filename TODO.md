# TODO - Prioritized Task List
## grey::static Development Roadmap

Last Updated: 2025-12-10

---

## PRIORITY 1: Fix Skipped Tests (HIGHEST)

### 1.1 Promise - Deeply Nested Flattening
**File:** `t/grey/static/04-concurrency/020-promise-advanced.t`
**Status:** SKIP block - "Deeply nested promise flattening not yet implemented"
**Description:** Promise->then() should flatten deeply nested promises (promise returning promise returning promise...)
**Action Required:**
- Investigate if this is needed (may be edge case)
- Implement promise flattening if required
- OR document why it's not needed and remove SKIP

---

## PRIORITY 2: Documentation (HIGH)

### 2.1 ScheduledExecutor POD
**File:** `lib/grey/static/concurrency/util/ScheduledExecutor.pm`
**Status:** Minimal documentation
**Action Required:**
- Add comprehensive POD documentation
- Document all methods with examples
- Explain queue-based timer architecture
- Include performance characteristics
- Add usage examples (delayed callbacks, cancellation)

### 2.2 Stream Time Operations POD
**Files:**
- `lib/grey/static/stream/Stream.pm` (methods: throttle, debounce, timeout)
- `lib/grey/static/stream/Stream/Operation/Throttle.pm`
- `lib/grey/static/stream/Stream/Operation/Debounce.pm`
- `lib/grey/static/stream/Stream/Operation/Timeout.pm`

**Status:** Implementation complete, documentation minimal
**Action Required:**
- Document throttle(), debounce(), timeout() methods in Stream.pm POD
- Add comprehensive POD to each Operation class
- Include examples showing time-based stream processing
- Explain how they differ from Flow (pull-based vs push-based)

### 2.3 Flow POD Enhancement
**Files:**
- `lib/grey/static/concurrency/reactive/Flow.pm`
- `lib/grey/static/concurrency/reactive/Flow/Publisher.pm`
- `lib/grey/static/concurrency/reactive/Flow/Subscriber.pm`
- `lib/grey/static/concurrency/reactive/Flow/Subscription.pm`
- `lib/grey/static/concurrency/reactive/Flow/Operation.pm`

**Status:** Some POD exists, needs enhancement
**Action Required:**
- Document backpressure mechanism
- Explain executor chaining
- Add comprehensive examples
- Document when to use Flow vs Stream
- Performance guidance (request_size optimization)

### 2.4 Promise POD Enhancement
**File:** `lib/grey/static/concurrency/util/Promise.pm`
**Status:** Has POD for timeout() and delay(), needs method documentation
**Action Required:**
- Document all Promise methods
- Add chaining examples
- Document error handling pattern (then(onSuccess, onError))
- Include integration examples with ScheduledExecutor

### 2.5 Executor POD
**File:** `lib/grey/static/concurrency/util/Executor.pm`
**Status:** Minimal documentation
**Action Required:**
- Document executor chaining with set_next()
- Explain cycle detection
- Document the event loop model
- Include examples

---

## PRIORITY 3: Project Documentation (MEDIUM)

### 3.1 CHANGELOG.md Update
**Status:** Not updated with timer integration features
**Action Required:**
- Document ScheduledExecutor addition
- Document Stream time operations (throttle, debounce, timeout)
- Document Promise timeout/delay features
- Reference benchmark results
- Note Timer::Wheel removal

### 3.2 README.md Review
**Status:** May need updates
**Action Required:**
- Review if timer/scheduling features should be mentioned
- Ensure feature list is current
- Add performance notes from benchmarks if relevant

### 3.3 Architecture Documentation
**Status:** Analysis docs exist but scattered
**Action Required:**
- Consider consolidating FLOW_INTEGRATION_ANALYSIS.md into architecture guide
- Maybe create docs/ARCHITECTURE.md with overall design
- Reference from README

---

## PRIORITY 4: Future Enhancements (LOW)

### 4.1 Benchmark Executor Overhead
**File:** `benchmarks/01-executor-overhead.pl`
**Status:** Created but not run (requires Memory::Usage module)
**Action Required:**
- Make benchmark work without Memory::Usage or make it optional
- Run and document results
- OR defer until performance concerns arise

### 4.2 Min-Heap Optimization for ScheduledExecutor
**Status:** Not needed yet
**Action Required:**
- Only implement if >1000 concurrent timers becomes common
- Current O(n) insertion adequate for typical use
- Benchmark first to validate need

### 4.3 Additional Integration Examples
**File:** `examples/concurrency-integration.pl` exists
**Action Required:**
- Consider adding real-world examples:
  - HTTP request timeout example
  - Rate-limited API client
  - Event processing pipeline
  - Background job scheduler

### 4.4 Flow Time Operations
**Status:** Decided NOT to implement (see FLOW_INTEGRATION_ANALYSIS.md)
**Action Required:**
- None - keep Flow and ScheduledExecutor separate
- Stream already has time operations for pull-based use cases

---

## COMPLETED ✅

- ✅ Timer::Wheel removal (replaced with queue-based ScheduledExecutor)
- ✅ ScheduledExecutor implementation (queue-based timers)
- ✅ Promise timeout() and delay() methods
- ✅ Stream time operations (throttle, debounce, timeout)
- ✅ Comprehensive benchmarking
- ✅ Flow integration analysis
- ✅ Integration examples
- ✅ All tests passing (except 1 SKIP)
- ✅ Documentation cleanup (removed historical prompts)
- ✅ Benchmark cleanup (removed Timer::Wheel benchmarks)

---

## NOT DOING ❌

- ❌ Flow + ScheduledExecutor integration (design mismatch - keep separate)
- ❌ Hierarchical Timer::Wheel (replaced with simpler queue approach)
- ❌ Executor-per-component optimization (acceptable tradeoff)

---

## Quick Reference

**Next Action:** Fix skipped Promise test or document why it's not needed
**After That:** Write POD documentation (ScheduledExecutor first, then Stream time ops)
**Timeline:** No rush - current design is solid and performant

---

## Files Cleaned Up

### Removed:
- docs/PROMISE_CHAINING_FIX_PROMPT.md
- docs/SESSION_SUMMARY.md
- docs/STREAM_TIME_OPERATIONS_PROMPT.md
- docs/TIMER_INTEGRATION_FIX_PROMPT.md
- docs/TIMER_INTEGRATION_PROMPT.md
- docs/timer-wheel-integration-ideas.md
- benchmarks/03-timer-wheel-performance.pl
- benchmarks/timer-wheel-find-next-timeout.pl
- benchmarks/01-stream-performance.pl
- benchmarks/02-functional-overhead.pl
- benchmarks/RESULTS.md
- lib/grey/static/time/wheel/ (entire directory)
- t/grey/static/07-time/ (Timer::Wheel tests)
- examples/time/ (Timer::Wheel examples)

### Kept:
- docs/BENCHMARK_RESULTS.md
- docs/FLOW_INTEGRATION_ANALYSIS.md
- docs/TIMER_INTEGRATION_STATUS.md
- benchmarks/01-executor-overhead.pl
- benchmarks/02-scheduled-executor.pl
- benchmarks/03-flow-throughput.pl
- benchmarks/04-stream-vs-flow.pl
- benchmarks/05-promise-scheduled-executor.pl
- examples/concurrency-integration.pl
