# Timer Integration Status Report
## Last Updated: 2025-12-09 (Complete Redesign - Queue-Based ScheduledExecutor)

## 🎉 FULLY WORKING - ALL TESTS PASSING

### Complete Redesign (2025-12-09)

**Problem Identified:** Fundamental design mismatch between hierarchical Timer::Wheel and ScheduledExecutor's event-driven model.

**Root Cause:**
- Timer::Wheel uses hierarchical bucketing (like an odometer) requiring tick-by-tick processing for timer cascading
- ScheduledExecutor jumps directly to next event for efficiency
- Timers added during callbacks were placed in higher-depth buckets that weren't checked when jumping
- Example: Timer at t=25 placed in bucket checked at t=20 and t=30, but executor jumped from t=10→t=25

**Solution:** Replaced Timer::Wheel with simple sorted queue based on Yakt::System::Timers pattern
- Array of `[expiry, id, callback, cancelled]` tuples
- O(n) insertion with fast-path optimizations for common cases (append to end)
- Direct expiry lookup - no cascading needed
- Lazy deletion of cancelled timers

**Files Completely Rewritten:**
- `lib/grey/static/concurrency/util/ScheduledExecutor.pm` - Queue-based implementation (~120 lines vs ~80 with wheel)

**Files Modified:**
- `lib/grey/static/concurrency/util/Promise.pm` - Fixed timeout() to avoid intermediate promise
- `t/grey/static/04-concurrency/030-scheduled-executor.t` - Updated for queue implementation
- `t/grey/static/04-concurrency/031-promise-timeout.t` - Unskipped complex chain test

**Impact:**
- Timer::Wheel no longer required for ScheduledExecutor
- All promise chaining now works correctly
- Much simpler, easier to understand implementation

## ✅ COMPLETED

### 1. Timer Cancellation (COMPLETE)
**Files Modified:**
- `lib/grey/static/time/wheel/Timer.pm` - Added `id` field
- `lib/grey/static/time/wheel/Timer/Wheel.pm` - Added tracking hash and `cancel_timer()` method
- Updated `check_timers()` to maintain tracking when timers move buckets
- `t/grey/static/07-time/004-timer-cancellation.t` - 7 comprehensive tests (ALL PASSING)

**Updated existing files:**
- `t/grey/static/07-time/002-timer-wheel-basic.t` - Added ID to all Timer->new() calls
- `t/grey/static/07-time/003-timer-wheel-limits.t` - Added ID to all Timer->new() calls
- `examples/time/timer-wheel.pl` - Added ID to Timer->new() calls
- `examples/timer-integration-prototype.pl` - Added ID to Timer->new() calls

### 2. Timer::Wheel Bug Fixes (CRITICAL)

#### 2a. find_next_timeout() Fix
**Problem:** The original `find_next_timeout()` calculated timeout from bucket index, returning incorrect values.

**Fix Applied:**
```perl
# OLD (BROKEN):
method find_next_timeout {
    foreach my ($i, $bucket) (indexed @wheel) {
        return $self->calculate_timeout_for_index($i)
            if scalar @$bucket;
    }
}

# NEW (CORRECT):
method find_next_timeout {
    my $min_expiry;
    foreach my $bucket (@wheel) {
        foreach my $timer (@$bucket) {
            if (!defined $min_expiry || $timer->expiry < $min_expiry) {
                $min_expiry = $timer->expiry;
            }
        }
    }
    return $min_expiry;
}
```

**Impact:** Fixes infinite loops with multiple timers. Changes complexity from O(1) to O(N).

#### 2b. add_timer() Delta-Based Bucket Calculation
**Problem:** When timers were added during callbacks (after wheel had advanced), they were placed in already-processed buckets.

**Fix Applied:**
```perl
method add_timer($timer) {
    # Calculate bucket based on delta from current wheel time
    my $current_time = $state->time;
    my $delta = $timer->expiry - $current_time;

    if ($delta <= 0) {
        Error->throw(
            message => "Cannot add timer in the past",
            hint => "Timer expiry must be greater than current wheel time"
        );
    }

    my $index = $self->calculate_first_index_for_time($delta);
    push @{$wheel[$index]} => $timer;
    # ... rest of implementation
}
```

**Impact:** Timers added during callbacks now go to correct future buckets.

**Known Limitation:** Delta-based bucketing causes issues with 3+ levels of nested delayed promises. Timers with delta calculations can conflict with absolute-time-based wheel design.

### 3. ScheduledExecutor Implementation (COMPLETE)

**Files Created:**
- `lib/grey/static/concurrency/util/ScheduledExecutor.pm`
- `t/grey/static/04-concurrency/030-scheduled-executor.t` - 13 tests (ALL PASSING)

**Files Modified:**
- `lib/grey/static/concurrency.pm` - Added ScheduledExecutor to `concurrency::util` feature

**Features Implemented:**
- `schedule_delayed($callback, $delay_ticks)` - Schedule callback with delay (minimum 1 tick)
- `cancel_scheduled($timer_id)` - Cancel scheduled callback
- `current_time()` - Get current executor time
- `wheel()` - Access timer wheel for inspection
- `run()` - Override with optimized time advancement logic

**Key Fixes:**

#### ScheduledExecutor->run() Optimization
**Problem:** Executor advanced time to next timer before processing queued callbacks, causing premature cancellations.

**Fix Applied:**
```perl
method run {
    while (!$self->is_done || $wheel->timer_count > 0) {
        # Process any queued callbacks first before advancing time
        if (!$self->is_done) {
            $self->tick;
            next;
        }

        # No queued callbacks - check if we should advance time
        my $next_timeout = $wheel->find_next_timeout;

        if (defined $next_timeout && $next_timeout > $current_time) {
            my $delta = $next_timeout - $current_time;
            $wheel->advance_by($delta);
            $current_time = $next_timeout;
            next;
        }

        # No queued callbacks and no timers - done
        last if $self->is_done && $wheel->timer_count == 0;
        last;  # Safety
    }
}
```

**Impact:** Callbacks can now cancel timers before executor advances to them.

### 4. Promise Timeout Support (COMPLETE - ALL TESTS PASSING)

**Files Modified:**
- `lib/grey/static/concurrency/util/Promise.pm` - Added `timeout()` method and `delay()` class method
- Full POD documentation added for both methods

**Files Created:**
- `t/grey/static/04-concurrency/031-promise-timeout.t` - 15 tests (ALL PASSING)

**Features Implemented:**

#### Promise->timeout($delay_ticks, $scheduled_executor) - FIXED

**Critical Fix Applied:** timeout() was creating intermediate promises that broke promise chaining.

**Problem:**
```perl
method timeout ($delay_ticks, $scheduled_executor) {
    # ...
    $self->then(  # <-- This creates an intermediate promise!
        sub ($value) { $timeout_promise->resolve($value) },
        sub ($error) { $timeout_promise->reject($error) }
    );
    return $timeout_promise;
}
```

**Solution:** Direct handler registration without intermediate promise
```perl
method timeout ($delay_ticks, $scheduled_executor) {
    # ...
    # Add handlers directly to avoid creating intermediate promise
    push @resolved => sub ($value) {
        $scheduled_executor->cancel_scheduled($timer_id);
        return unless $timeout_promise->is_in_progress;
        $timeout_promise->resolve($value);
    };
    push @rejected => sub ($error) {
        $scheduled_executor->cancel_scheduled($timer_id);
        return unless $timeout_promise->is_in_progress;
        $timeout_promise->reject($error);
    };
    # If already settled, notify immediately
    $self->_notify unless $self->is_in_progress;
    return $timeout_promise;
}
```

**Features:**
- Adds timeout to existing promises
- Returns new promise that rejects if timeout elapses
- Automatically cancels timeout timer if promise settles first
- Guards against double-settlement with `is_in_progress` checks
- **Now works correctly in promise chains!**

**Example:**
```perl
my $executor = ScheduledExecutor->new;
my $promise = Promise->new(executor => $executor);

$promise->timeout(100, $executor)
    ->then(
        sub ($value) { say "Success: $value" },
        sub ($error) { say "Error: $error" }
    );

$executor->schedule_delayed(sub { $promise->resolve("Done!") }, 50);
$executor->run;  # Resolves before timeout
```

#### Promise->delay($value, $delay_ticks, $scheduled_executor)
- Factory method for creating delayed promises
- Returns promise that resolves with value after delay
- Supports promise chaining and transformations

**Example:**
```perl
my $executor = ScheduledExecutor->new;

Promise->delay("Hello", 10, $executor)
    ->then(sub ($x) { $x . " World" })
    ->then(sub ($x) { say $x });

$executor->run;  # Prints "Hello World" after 10 ticks
```

**Implementation Details:**
- `delay()` implemented as BEGIN block outside class to support class method syntax
- Uses `*{'Promise::delay'} = sub { ... }` pattern for compatibility with Perl's class system

## ✅ All Known Issues Resolved

### Former Issue #1: Deep Promise Nesting
**Status:** RESOLVED by queue-based executor redesign
- No longer relevant - hierarchical bucketing removed

### Former Issue #2: Complex Promise Chaining
**Status:** RESOLVED by two fixes:
1. **Promise->timeout() fix:** Removed intermediate promise creation
2. **ScheduledExecutor redesign:** Queue-based approach eliminates timer wheel cascading issues

**Previously Failing Test Now Passes:**
```perl
# Complex chain with multiple delays + timeouts
$fetch_user->(123)
    ->then($fetch_posts)  # Returns Promise->delay()->timeout()
    ->then(sub { ... });  # NOW WORKS! ✅
```

### Performance Characteristics
**Current Implementation:** Simple sorted queue
- O(n) insertion with fast-path optimizations
- O(1) next timer lookup (first element)
- O(n) cancellation (lazy deletion)

**Trade-offs:**
- Simpler and more correct than hierarchical wheel
- Adequate performance for typical use cases (<1000 timers)
- Future optimization possible with min-heap if needed

## ✅ Stream Time Operations (COMPLETE)

**Files Implemented:**
- `lib/grey/static/stream/Stream/Operation/Debounce.pm` - Buffer values and emit last after quiet period
- `lib/grey/static/stream/Stream/Operation/Throttle.pm` - Rate limit element emission with minimum delay
- `lib/grey/static/stream/Stream/Operation/Timeout.pm` - Throw error if no elements within timeout

**Integration:**
- Loaded in `lib/grey/static/stream/Stream.pm` (lines 15, 29, 30)
- Methods added to Stream class:
  - `throttle($min_delay, $executor)` - lib/grey/static/stream/Stream.pm:376
  - `debounce($quiet_delay, $executor)` - lib/grey/static/stream/Stream.pm:387
  - `timeout($timeout_delay, $executor)` - lib/grey/static/stream/Stream.pm:398

**Tests:**
- `t/grey/static/02-stream/040-time-operations.t` - 21 tests (ALL PASSING)
  - 5 throttle tests
  - 5 debounce tests
  - 5 timeout tests
  - 6 integration tests (chaining, composition)

## 📋 Not Yet Implemented

### 1. Flow Integration
**Status:** Analysis complete - **No integration recommended**

See `docs/FLOW_INTEGRATION_ANALYSIS.md` for comprehensive deep dive.

**Summary:**
- Flow and ScheduledExecutor serve different purposes (reactive streams vs time simulation)
- Flow uses executor chaining with backpressure control
- ScheduledExecutor's time advancement incompatible with executor chaining
- Stream already has time operations (throttle, debounce, timeout) for pull-based use cases
- **Recommendation:** Keep Flow and ScheduledExecutor separate, use as complementary tools

**Next Steps:**
- Document architecture and usage patterns
- Create examples showing both used together (complementary, not integrated)
- Benchmark if performance concerns arise (optional)
- Consider integration tests for Flow + Promise scenarios

### 2. Documentation & Examples
**Needed:**
- POD for ScheduledExecutor (currently minimal)
- POD for Stream time operations (throttle, debounce, timeout)
- Working demonstration: `examples/scheduled-execution-demo.pl`
- Update CHANGELOG.md with timer integration features
- Update README.md if needed

## Test Results Summary

**All Tests Passing - No Skips:**
- Timer tests: 23 tests across 4 files ✅
- ScheduledExecutor tests: 13 tests ✅
- Promise timeout tests: **15 tests (ALL PASSING, none skipped)** ✅
- Stream time operations: 21 tests ✅
- Full concurrency suite: **225 tests across 23 files** ✅
- **Full project test suite: All passing** ✅

## Technical Notes

### Queue-Based ScheduledExecutor Design

**Timer Storage:**
```perl
field @timers;  # Array of [expiry, id, callback, cancelled]
```

**Insertion Strategy:**
1. Empty queue → push directly
2. New timer >= last timer → append (common case, O(1))
3. Otherwise → binary search and splice (O(n))

**Execution Flow:**
```perl
method run {
    while (!$self->is_done || @timers) {
        # Process queued callbacks first
        if (!$self->is_done) {
            $self->tick;
            next;
        }

        # Advance to next timer
        my $next_expiry = $self->_find_next_expiry;  # Skip cancelled
        if (defined $next_expiry && $next_expiry > $current_time) {
            $current_time = $next_expiry;
            my @pending = $self->_get_pending_timers;  # All at current time
            $_->[2]->() for @pending;  # Execute callbacks
        }
    }
}
```

**Time Model:**
- `current_time` starts at 0
- `schedule_delayed(cb, delay)` creates timer at `current_time + max(delay, 1)`
- Minimum delay of 1 enforced to avoid same-time scheduling
- Time jumps directly to next timer expiry (no tick-by-tick processing needed)
- Queued callbacks are processed before time advancement

### Promise Timeout Pattern
```perl
my $executor = ScheduledExecutor->new;

# Timeout on existing promise
my $promise = Promise->new(executor => $executor);
$promise->timeout(30, $executor)
    ->then(
        sub ($value) { say "Success: $value" },
        sub ($error) { say "Error: $error" }
    );

# Delayed promise with timeout
Promise->delay("data", 10, $executor)
    ->timeout(50, $executor)
    ->then(sub ($x) { say $x });

# Chained delayed promises
Promise->delay("A", 10, $executor)
    ->then(sub ($x) {
        say $x;
        return Promise->delay("B", 5, $executor);
    })
    ->then(sub ($x) { say $x });

$executor->run;
```

## Design Lessons Learned

### Why Timer::Wheel Failed

**Hierarchical Timer Wheels** are designed for:
- Scenarios where most timers are added upfront
- Tick-by-tick advancement (real-time systems, game loops)
- Predictable cascade patterns as time advances

**ScheduledExecutor needs:**
- Dynamic timer addition during callback execution
- Sparse time simulation (jump to next event)
- No wasted processing of empty time slices

**The Mismatch:**
- Wheel uses gear-based state machine that checks specific buckets on gear rollovers
- Timer at t=25 placed in bucket checked only at t=20, t=30, etc.
- Jumping from t=10→t=25 skips the t=20 cascade point
- Timer never reaches depth-0 bucket where it would fire

**Key Insight:** When porting code from different projects (Timer::Wheel from p7, Promises from another context), verify that fundamental assumptions are compatible. A hierarchical timer wheel optimized for real-time tick processing doesn't fit an event-driven sparse-time executor.

### Why Queue Works

**Simplicity:**
- Direct expiry comparison, no bucket calculations
- No cascading or depth management
- Easy to reason about correctness

**Correctness:**
- Timer fires when `current_time >= expiry` - that's it
- No hidden state machine or gear positions
- Works correctly whether time advances 1 tick or 1000 ticks

**Performance:**
- O(n) worst case but O(1) for append-to-end (common case)
- Good enough for typical usage (<100 concurrent timers)
- Can optimize later with heap if needed

## Next Steps

All timer integration work is complete. The system now has:
- Working ScheduledExecutor with correct timer semantics
- Full Promise timeout and delay support
- Complex promise chaining working correctly
- All tests passing

Possible future enhancements:
- Min-heap optimization for O(log n) operations if timer count grows
- Stream time operations (debounce, throttle, timeout) - see `docs/STREAM_TIME_OPERATIONS_PROMPT.md`
