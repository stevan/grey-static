# Flow::Publisher::Zip - Completion Timing Issue

**Date:** 2025-12-10
**Status:** Implementation Problem - Solvable
**Affected:** Zip publisher (Merge and Concat work correctly)

## Executive Summary

**Verdict: This is an implementation problem, not a design flaw.**

The core reactive streams design is sound. The issue is that Zip's completion logic doesn't properly account for the multi-level asynchronous scheduling inherent in the Flow architecture. The problem is solvable within the current design.

## The Problem

Zip produces **some** correct results but loses others due to premature completion. Values are combined correctly by the combiner function, but not all combined values reach the final subscriber before completion terminates the stream.

### Observed Behavior

Test case:
```perl
pub1->submit(1);  pub1->submit(2);
pub2->submit(10); pub2->submit(20);
pub1->close;
pub2->close;

# Expected pairs: (1,10), (2,20) -> results: ['1-10', '2-20']
# Actual: '1-10' delivered, '2-20' lost
```

Event trace shows:
```
combiner(1, 10)  ✓ Called
combiner(2, 20)  ✓ Called
result: 1-10     ✓ Delivered
result: 2-20     ✗ Lost - never delivered
```

## Root Cause Analysis

### 1. Multi-Level Asynchronous Scheduling

The Flow architecture uses `executor->next_tick()` for async scheduling. This creates multiple levels of async operations:

**Level 1: Publisher submit/drain**
```perl
# Publisher.pm
method submit ($value) {
    push @buffer => $value;
    $executor->next_tick(sub {
        $self->drain_buffer;  # Scheduled for next tick
    });
}
```

**Level 2: Subscription offer/drain**
```perl
# Subscription.pm
method offer ($e) {
    push @buffer => $e;
    if ($requested) {
        $executor->next_tick(sub {
            $self->drain_buffer;  # ANOTHER next_tick
        });
    }
}

method drain_buffer {
    while (@buffer && $requested) {
        my $next = shift @buffer;
        $executor->next_tick(sub {
            $self->on_next($next);  # YET ANOTHER next_tick
        });
    }
}
```

**Result:** From `offer($value)` to final delivery takes **TWO ticks**:
- Tick N: `offer()` schedules `drain_buffer()`
- Tick N+1: `drain_buffer()` runs, schedules `on_next()`
- Tick N+2: `on_next()` delivers value to subscriber

### 2. Executor Chaining

When executors are chained via `set_next()`:
```perl
pub1_executor -> zip_executor
pub2_executor -> zip_executor
```

The execution flow is:
```
pub1->close():
  1. pub1's executor runs (processes pub1 events)
  2. zip's executor runs (processes zip events so far)

pub2->close():
  3. pub2's executor runs (processes pub2 events)
  4. zip's executor runs again (processes new zip events)
```

**Critical point:** Zip's executor runs BETWEEN pub1's events and pub2's events, not after BOTH complete.

### 3. The Completion Race

Current implementation (simplified):
```perl
method on_source_completed ($source_index) {
    $completed_count++;
    $self->try_emit();  # Emit remaining pairs

    # Complete downstream
    $downstream_subscription->on_completed;
}

method try_emit {
    # Combine and emit
    $downstream_subscription->offer($combined);  # Schedules delivery in 2 ticks

    $self->try_emit();  # Recursive
}
```

**The race:**
1. `try_emit()` calls `offer($combined)` - value delivery scheduled for +2 ticks
2. `try_emit()` recurses, eventually returns
3. `on_source_completed()` calls `on_completed` - completion scheduled for +1 tick
4. **Completion happens before value delivery!**

Timeline:
```
Tick 0: offer(2-20) scheduled
Tick 1: on_completed scheduled, drain_buffer scheduled
Tick 2: on_completed executes (stream completes)
Tick 3: on_next(2-20) executes (but stream already completed, value lost)
```

### 4. Why Merge and Concat Don't Have This Problem

**Merge:**
- Sources can complete independently
- No buffering/pairing logic - just forward as values arrive
- Completes only when ALL sources complete
- Values are forwarded before completion check

**Concat:**
- Only one source active at a time
- Sequential processing eliminates timing races
- Next source only starts after previous fully drains
- Natural ordering prevents completion races

**Zip:**
- Must coordinate MULTIPLE sources simultaneously
- Buffers values from each source
- Pairs must be formed from buffered values
- Completion should happen when pairing is impossible
- **But: pairing logic + completion logic = timing race**

## Why This Is An Implementation Problem, Not Design Flaw

### Design Is Sound

1. **Reactive Streams model works:** Merge and Concat prove the architecture is correct
2. **Async scheduling is necessary:** Prevents blocking, enables backpressure
3. **Executor chaining solves coordination:** Merge/Concat prove this works
4. **The pattern is proven:** Flow::Operation uses same patterns successfully

### Implementation Gap

The issue is that Zip's implementation doesn't account for:

1. **Multi-tick delivery latency:** `offer()` takes 2 ticks to deliver
2. **Multiple completion signals:** Each source completion triggers completion logic
3. **Buffered state vs completion:** Need to drain buffers before completing
4. **Async ordering guarantees:** Must ensure offers complete before on_completed

## Attempted Solutions & Why They Failed

### Attempt 1: Wait for ALL sources to complete
```perl
if ($completed_count >= scalar(@$sources)) {
    $downstream_subscription->on_completed;
}
```
**Result:** Better, but still lost values. The 2-tick delivery delay means completion still races with the last emission.

### Attempt 2: Double next_tick for completion
```perl
$self->executor->next_tick(sub {
    $self->executor->next_tick(sub {
        $downstream_subscription->on_completed;
    });
});
```
**Result:** Helps but unreliable. We're guessing at the right delay rather than ensuring ordering.

### Attempt 3: Prevent multiple completions with flag
```perl
field $downstream_completed = 0;

if (!$downstream_completed) {
    $downstream_completed = 1;
    # ... schedule completion
}
```
**Result:** Prevents duplicate completion calls but doesn't solve delivery timing.

## The Correct Solution (Not Yet Implemented)

The proper solution requires ensuring that completion happens AFTER all pending offers are processed:

### Option A: Synchronous Completion After Drain

Wait until buffers are fully drained before completing:

```perl
method on_source_completed ($source_index) {
    $completed_count++;
    $any_completed = 1;

    # Don't complete yet - just mark as "should complete"
    $self->check_for_completion();
}

method try_emit {
    # Emit all possible pairs
    while (all buffers have items) {
        emit pair
    }

    # After emitting, check if we should complete
    $self->check_for_completion();
}

method check_for_completion {
    return unless $any_completed;  # No source completed yet
    return if any buffer has items; # Can still form pairs
    return if $downstream_completed; # Already completed

    # Now safe to complete - all pairs emitted
    $downstream_completed = 1;
    $downstream_subscription->on_completed;
}
```

### Option B: Completion Counter

Track pending emissions and only complete when all are delivered:

```perl
field $pending_emissions = 0;

method try_emit {
    # emit pair
    $pending_emissions++;
    $downstream_subscription->offer($combined);
}

# In a wrapper around the final subscriber's on_next:
method on_value_delivered {
    $pending_emissions--;
    $self->check_for_completion();
}

method check_for_completion {
    return unless $any_completed;
    return if $pending_emissions > 0;  # Wait for pending deliveries
    return if $downstream_completed;

    $downstream_completed = 1;
    $downstream_subscription->on_completed;
}
```

### Option C: Callback-Based Completion

Use a completion callback that fires after offer completes:

```perl
method try_emit {
    # emit pair
    $downstream_subscription->offer($combined, on_complete => sub {
        # This fires after value is delivered
        $self->check_for_completion();
    });
}
```

This would require modifying `Subscription::offer` to accept completion callbacks.

## Recommended Path Forward

**Recommendation: Option A (Synchronous Completion Check)**

Reasons:
1. Doesn't require changing core Subscription API
2. Clear, understandable logic
3. Separates emission from completion
4. Zip controls its own completion timing

Implementation:
1. Remove completion logic from `on_source_completed`
2. Add `check_for_completion` method
3. Call it after `try_emit` completes
4. Only complete when: `$any_completed && all_buffers_empty`

## Expected Test Results After Fix

All 4 zip tests should pass:

1. **zip - two publishers with BiFunction** ✓
   - Pairs: (1,10), (2,20), (3,30)
   - All pairs delivered before completion

2. **zip - uneven lengths** ✓
   - Pairs: (1,10), (2,20)
   - Completes when shorter source exhausts
   - No extra/missing values

3. **zip - with BiFunction object** ✓
   - Uses BiFunction instead of lambda
   - Same pairing behavior

4. **zip - with operations** ✓
   - Zip then map then filter
   - All operations receive correct values
   - Completion propagates correctly

## Testing Strategy

### Unit Tests
```perl
# Test: Emit all buffered pairs before completion
my $pub1 = Flow::Publisher->new;
my $pub2 = Flow::Publisher->new;

# Pre-submit all values before any close
$pub1->submit($_) for 1..5;
$pub2->submit($_) for 10..14;

# Then close
$pub1->close;
$pub2->close;

# Should get ALL 5 pairs
is(scalar(@results), 5, 'All pairs emitted');
```

### Integration Tests
```perl
# Test: Zip with slow consumer
# Ensure backpressure doesn't cause lost values

# Test: Zip with operations
# Ensure chained operations see all values

# Test: Zip completion propagation
# Ensure on_completed reaches final subscriber exactly once
```

## Comparison to Other Reactive Frameworks

### RxJS (JavaScript)
```javascript
zip(source1$, source2$).subscribe(...)
```
- Buffers values from each source
- Emits pairs synchronously as soon as both have values
- Completes when ANY source completes
- **No async delivery race** (JavaScript event loop guarantees)

### Reactor (Java)
```java
Flux.zip(source1, source2).subscribe(...)
```
- Uses synchronized queues for buffering
- Thread-safe coordination between sources
- **No race** due to synchronization primitives

### Our Implementation
```perl
Flow::Publishers->zip($pub1, $pub2)
```
- Async scheduling via next_tick
- No synchronization primitives
- **Must carefully order async operations**

The difference: Other frameworks have stronger ordering guarantees (event loop or threads). We must explicitly manage async ordering.

## Conclusion

**This is definitively an implementation problem, not a design flaw.**

Evidence:
1. ✅ The design works for Merge and Concat
2. ✅ The async model is necessary and correct
3. ✅ Executor chaining solves the coordination problem
4. ✅ The issue is specific to Zip's buffering + completion logic
5. ✅ Clear implementation path exists (Option A)

The fix is to separate completion logic from emission logic and ensure completion only happens after all buffered pairs are emitted and delivered. The multi-tick delivery latency must be accounted for, not worked around.

## Next Steps

1. Implement Option A (synchronous completion check)
2. Remove all timing-based workarounds (double next_tick)
3. Add comprehensive tests for edge cases
4. Document the completion semantics clearly
5. Consider adding completion callbacks to Subscription (future work)

---

**Key Insight:** The bug exists because we're trying to race against async scheduling rather than coordinating with it. The fix is to work WITH the async model, not against it.
