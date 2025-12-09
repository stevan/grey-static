# Implementation Prompt: Timer::Wheel + Executor Integration

## Context

The grey::static project has two powerful but **isolated** async features:

1. **Timer::Wheel** (`lib/grey/static/time/wheel/Timer/Wheel.pm`)
   - Hierarchical timing wheel with O(1) operations
   - Benchmarked: ~1µs per timer, scales linearly to 10k+ timers
   - Currently standalone - only used in examples
   - Manual advancement only (no event loop)

2. **Executor** (`lib/grey/static/concurrency/util/Executor.pm`)
   - Simple async callback queue
   - Used by Promise for async resolution
   - No timer/scheduling support

3. **Promise** (`lib/grey/static/concurrency/util/Promise.pm`)
   - JavaScript-style promises
   - No timeout support
   - No delayed resolution

## Goal

Integrate Timer::Wheel with Executor to create a **time-aware event loop** that enables:

- ✅ Promise timeouts (`$promise->timeout(5000)`)
- ✅ Delayed execution (`$executor->schedule_delayed($cb, 1000)`)
- ✅ Stream time operations (throttle, debounce, timeout)
- ✅ Unified timing mechanism across all async features

## Implementation Tasks

### Task 1: Add Timer Cancellation (~30-45 min)

**Files to modify:**
- `lib/grey/static/time/wheel/Timer.pm`
- `lib/grey/static/time/wheel/Timer/Wheel.pm`

**Changes:**

1. **Add ID field to Timer:**
```perl
# In lib/grey/static/time/wheel/Timer.pm
class Timer {
    use overload '""' => \&to_string;
    field $id     :param :reader;  # NEW: unique ID
    field $expiry :param :reader;
    field $event  :param :reader;

    method to_string {
        sprintf 'Timer[%d,id=%s]' => $expiry, $id;
    }
}
```

2. **Add cancellation to Timer::Wheel:**
```perl
# In lib/grey/static/time/wheel/Timer/Wheel.pm

# Add field to track timers by ID
field %timers_by_id;  # id => {timer, bucket_index}

# Modify add_timer to track by ID
method add_timer($timer) {
    Error->throw(...) if $timer_count >= MAX_TIMERS;

    my $index = $self->calculate_first_index_for_time($timer->expiry);
    push @{$wheel[$index]} => $timer;
    $timer_count++;

    # Track for cancellation
    $timers_by_id{$timer->id} = {
        timer => $timer,
        bucket_index => $index
    };
}

# Add cancel_timer method
method cancel_timer($timer_id) {
    my $info = delete $timers_by_id{$timer_id};
    return 0 unless $info;  # Not found

    my $bucket = $wheel[$info->{bucket_index}];
    my $timer = $info->{timer};

    # Remove from bucket
    @$bucket = grep { $_->id ne $timer_id } @$bucket;
    $timer_count--;

    return 1;  # Success
}
```

3. **Update tests:**
- Add `t/grey/static/07-time/004-timer-cancellation.t`
- Test cancel before firing, cancel after firing, cancel non-existent

### Task 2: Create ScheduledExecutor (~1-2 hours)

**New file:** `lib/grey/static/concurrency/util/ScheduledExecutor.pm`

**Implementation:**
```perl
use v5.42;
use experimental qw[ class ];

use grey::static qw[ time::wheel ];

class ScheduledExecutor :isa(Executor) {
    field $wheel = Timer::Wheel->new;
    field $current_time = 0;
    field $next_timer_id = 1;

    # Schedule callback with delay
    method schedule_delayed($callback, $delay_ticks) {
        my $timer_id = $next_timer_id++;
        my $expiry = $current_time + $delay_ticks;

        my $timer = Timer->new(
            id     => $timer_id,
            expiry => $expiry,
            event  => sub { $self->next_tick($callback) }
        );

        $wheel->add_timer($timer);
        return $timer_id;
    }

    # Cancel scheduled callback
    method cancel_scheduled($timer_id) {
        return $wheel->cancel_timer($timer_id);
    }

    # Get current time
    method current_time { $current_time }

    # Get timer wheel (for inspection/debugging)
    method wheel { $wheel }

    # Override run() to advance time
    method run {
        while (1) {
            # Check if we're done
            my $has_callbacks = !$self->is_done;
            my $has_timers = $wheel->timer_count > 0;

            last unless $has_callbacks || $has_timers;

            # If we have timers, advance to next one
            if ($has_timers) {
                my $next_timeout = $wheel->find_next_timeout;

                if (defined $next_timeout && $next_timeout > $current_time) {
                    my $delta = $next_timeout - $current_time;
                    $wheel->advance_by($delta);
                    $current_time = $next_timeout;
                }
            }

            # Run one tick of callbacks
            $self->tick;
        }
    }
}

1;
```

**Update feature loader:**
- Modify `lib/grey/static/concurrency.pm` to load ScheduledExecutor

**Tests:**
- Create `t/grey/static/04-concurrency/030-scheduled-executor.t`
- Test delayed execution, cancellation, time advancement

### Task 3: Add Promise Timeout Support (~30-45 min)

**File to modify:** `lib/grey/static/concurrency/util/Promise.pm`

**Add method:**
```perl
method timeout($timeout_ticks, $executor) {
    # Executor must be ScheduledExecutor
    Error->throw(
        message => "Invalid executor for timeout",
        hint => "Expected ScheduledExecutor, got: " . ref($executor)
    ) unless $executor->can('schedule_delayed');

    my $timeout_promise = Promise->new(executor => $executor);

    # Schedule timeout
    my $timer_id = $executor->schedule_delayed(
        sub {
            $timeout_promise->reject("Timeout after ${timeout_ticks} ticks");
        },
        $timeout_ticks
    );

    # Forward resolution/rejection, cancel timer
    $self->then(
        sub ($value) {
            $executor->cancel_scheduled($timer_id);
            $timeout_promise->resolve($value);
        },
        sub ($error) {
            $executor->cancel_scheduled($timer_id);
            $timeout_promise->reject($error);
        }
    );

    return $timeout_promise;
}
```

**Add factory method:**
```perl
sub Promise::delay($class, $value, $delay_ticks, $executor) {
    Error->throw(
        message => "Invalid executor for delay",
        hint => "Expected ScheduledExecutor"
    ) unless $executor->can('schedule_delayed');

    my $p = Promise->new(executor => $executor);

    $executor->schedule_delayed(
        sub { $p->resolve($value) },
        $delay_ticks
    );

    return $p;
}
```

**Tests:**
- Create `t/grey/static/04-concurrency/031-promise-timeout.t`
- Test timeout success, timeout failure, delay

### Task 4: Add Stream Time Operations (~1-2 hours)

**New files:**
- `lib/grey/static/stream/Stream/Operation/Throttle.pm`
- `lib/grey/static/stream/Stream/Operation/Debounce.pm`
- `lib/grey/static/stream/Stream/Operation/Timeout.pm`

**Throttle implementation:**
```perl
class Stream::Operation::Throttle :isa(Stream::Operation) {
    field $min_interval :param;
    field $executor     :param;

    field $last_emit_time = 0;

    method execute ($source) {
        while ($source->has_next) {
            my $element = $source->next;
            my $now = $executor->current_time;

            if ($now - $last_emit_time >= $min_interval) {
                $last_emit_time = $now;
                return $element;
            }
            # else: drop element (too soon)
        }
        return undef;
    }
}
```

**Add to Stream:**
```perl
# In lib/grey/static/stream/Stream.pm
method throttle($interval, $executor) {
    return $self->pipe(
        Stream::Operation::Throttle->new(
            min_interval => $interval,
            executor     => $executor
        )
    );
}
```

**Tests:**
- Create `t/grey/static/02-stream/040-time-operations.t`

### Task 5: Documentation & Examples (~30 min)

**Update POD in:**
- `lib/grey/static/concurrency/util/ScheduledExecutor.pm`
- `lib/grey/static/concurrency/util/Promise.pm`
- `lib/grey/static/stream/Stream.pm`

**Create example:**
- `examples/scheduled-execution-demo.pl`

**Update:**
- `README.md` - Add ScheduledExecutor to features
- `CHANGELOG.md` - Document new capabilities

## Success Criteria

- ✅ All existing tests pass (904 tests)
- ✅ New tests for Timer cancellation (>10 tests)
- ✅ New tests for ScheduledExecutor (>15 tests)
- ✅ New tests for Promise timeout (>10 tests)
- ✅ New tests for Stream time operations (>10 tests)
- ✅ Working example demonstrating all features
- ✅ Complete POD documentation

## Implementation Order

1. **Timer cancellation** (foundation for everything else)
2. **ScheduledExecutor** (core integration)
3. **Promise timeout** (high-value quick win)
4. **Promise delay** (easy addition)
5. **Stream throttle** (demonstrates pattern)
6. **Stream debounce** (if time permits)
7. **Documentation & examples**

## Technical Notes

**Time Units:**
- Use "ticks" as abstract time units (not milliseconds)
- This keeps Timer::Wheel abstract and testable
- ScheduledExecutor can be subclassed for real-time if needed

**Executor Compatibility:**
- Regular Executor should still work for non-time-aware code
- ScheduledExecutor is backward compatible (is-a Executor)
- Promise/Stream should accept either, check capabilities

**Error Handling:**
- Use Error->throw() for validation (consistent with codebase)
- Provide helpful hints in error messages
- Validate executor capabilities before scheduling

## Reference Files

- **Design doc:** `docs/timer-wheel-integration-ideas.md`
- **Benchmark results:** `benchmarks/RESULTS.md`
- **Existing Timer::Wheel:** `lib/grey/static/time/wheel/Timer/Wheel.pm`
- **Existing Executor:** `lib/grey/static/concurrency/util/Executor.pm`
- **Existing Promise:** `lib/grey/static/concurrency/util/Promise.pm`

## Questions to Resolve

1. Should ScheduledExecutor be the default for Promises?
2. Should we add recurring timers (intervals) in this phase?
3. Should Stream time operations be a separate feature (stream::time)?
4. Should we add real-time ScheduledExecutor variant now or later?

## Estimated Effort

- **Core implementation:** 3-4 hours
- **Testing:** 2-3 hours
- **Documentation:** 1 hour
- **Total:** 6-8 hours

This enables a powerful new capability tier for grey::static with minimal risk to existing code.
