# Prompt: Implement Stream Time Operations

## Objective

Implement time-based stream operations (Throttle, Debounce, Timeout) that integrate ScheduledExecutor with the existing Stream API, enabling reactive streams with temporal controls.

## Prerequisites - What's Already Working

✅ **ScheduledExecutor** - Timer-based event loop with time advancement
✅ **Promise timeout/delay** - Promises with temporal controls
✅ **Stream API** - Functional reactive streams with operations and collectors
✅ **All tests passing** - 924 tests across 100 files

## Context: Existing Stream Architecture

### Stream Class Structure
```
lib/grey/static/stream/
├── Stream.pm                    # Main Stream class
├── Stream/
│   ├── Source/                  # Stream sources (FromArray, FromRange, etc.)
│   │   ├── FromArray.pm
│   │   ├── FromRange.pm
│   │   └── ...
│   ├── Operation/               # Stream operations (Map, Filter, etc.)
│   │   ├── Map.pm
│   │   ├── Filter.pm
│   │   ├── Take.pm
│   │   └── ...
│   └── Collector/               # Terminal operations (ToArray, Reduce, etc.)
│       ├── ToArray.pm
│       ├── Reduce.pm
│       └── ...
```

### Stream Operation Pattern

All stream operations follow this pattern:

```perl
use v5.42;
use experimental qw[ class ];

class Stream::Operation::OperationName :isa(Stream::Operation) {
    field $source :param;
    # Operation-specific fields

    method has_next {
        # Check if operation can produce next element
    }

    method next {
        # Produce next element
    }
}
```

### Adding Operations to Stream Class

Operations are exposed via methods in `lib/grey/static/stream/Stream.pm`:

```perl
method operation_name(...) {
    Stream::Operation::OperationName->new(source => $self, ...);
}
```

## Task 1: Implement Stream::Operation::Throttle

### Design Specification

**Purpose:** Drop elements that arrive too quickly. Only emit elements that are separated by at least `$min_delay` ticks.

**Behavior:**
- First element is always emitted immediately
- Subsequent elements are only emitted if `>= $min_delay` ticks have elapsed since last emission
- Elements that arrive too quickly are dropped (not buffered)
- Integrates with ScheduledExecutor's time model

### Implementation Location
- **Class:** `lib/grey/static/stream/Stream/Operation/Throttle.pm`
- **Method:** Add `throttle($min_delay, $executor)` to `lib/grey/static/stream/Stream.pm`

### Implementation Guidance

```perl
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Throttle :isa(Stream::Operation) {
    field $source :param;
    field $min_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $last_emit_time = undef;

    method has_next {
        return 0 unless $source->has_next;

        # First element or enough time has passed
        if (!defined $last_emit_time) {
            return 1;
        }

        my $current_time = $executor->current_time;
        return ($current_time - $last_emit_time) >= $min_delay;
    }

    method next {
        die "No more elements" unless $self->has_next;

        my $value = $source->next;
        $last_emit_time = $executor->current_time;

        return $value;
    }
}
```

**Note:** Throttle operates in "pull" mode - it checks timing when `next()` is called. For time-based emission, the executor must advance time between pulls.

### Test Cases
```perl
# Test 1: First element passes immediately
# Test 2: Elements within min_delay are dropped
# Test 3: Elements after min_delay pass through
# Test 4: Multiple throttle operations can be chained
# Test 5: Works with executor time advancement
```

## Task 2: Implement Stream::Operation::Debounce

### Design Specification

**Purpose:** Only emit elements after a "silence period" - when no new elements arrive for `$quiet_delay` ticks.

**Behavior:**
- Buffer the most recent element
- Only emit when `$quiet_delay` ticks pass with no new elements
- Each new element resets the quiet timer
- Final element is emitted when stream ends

### Implementation Location
- **Class:** `lib/grey/static/stream/Stream/Operation/Debounce.pm`
- **Method:** Add `debounce($quiet_delay, $executor)` to `lib/grey/static/stream/Stream.pm`

### Implementation Guidance

```perl
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Debounce :isa(Stream::Operation) {
    field $source :param;
    field $quiet_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $buffered_value = undef;
    field $has_buffered = 0;
    field $last_update_time = undef;

    method has_next {
        # Pull source elements while available
        while ($source->has_next) {
            $buffered_value = $source->next;
            $has_buffered = 1;
            $last_update_time = $executor->current_time;
        }

        # Check if quiet period has elapsed
        if ($has_buffered && defined $last_update_time) {
            my $current_time = $executor->current_time;
            my $elapsed = $current_time - $last_update_time;

            if ($elapsed >= $quiet_delay) {
                return 1;
            }
        }

        return 0;
    }

    method next {
        die "No more elements" unless $self->has_next;

        my $value = $buffered_value;
        $has_buffered = 0;
        $buffered_value = undef;

        return $value;
    }
}
```

**Challenge:** Debounce requires "push" semantics (emit after delay) but streams are "pull" based. Solution: The collector/consumer must advance executor time to trigger the quiet period check.

### Test Cases
```perl
# Test 1: Single element emits after quiet_delay
# Test 2: Rapid elements only emit the last one after quiet_delay
# Test 3: Multiple debounce periods work correctly
# Test 4: Stream end triggers final emission
# Test 5: Works with scheduled executor time advancement
```

## Task 3: Implement Stream::Operation::Timeout

### Design Specification

**Purpose:** Error if no element is produced within `$timeout_delay` ticks.

**Behavior:**
- Track time since last element
- If no element arrives within `$timeout_delay`, throw error
- Timer resets with each successful element
- Integrates with executor's time model

### Implementation Location
- **Class:** `lib/grey/static/stream/Stream/Operation/Timeout.pm`
- **Method:** Add `timeout($timeout_delay, $executor)` to `lib/grey/static/stream/Stream.pm`

### Implementation Guidance

```perl
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Stream::Operation::Timeout :isa(Stream::Operation) {
    field $source :param;
    field $timeout_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $last_element_time = 0;

    method has_next {
        my $current_time = $executor->current_time;
        my $elapsed = $current_time - $last_element_time;

        if ($elapsed >= $timeout_delay) {
            Error->throw(
                message => "Stream timeout",
                hint => "No element received within $timeout_delay ticks"
            );
        }

        return $source->has_next;
    }

    method next {
        die "No more elements" unless $self->has_next;

        my $value = $source->next;
        $last_element_time = $executor->current_time;

        return $value;
    }
}
```

### Test Cases
```perl
# Test 1: Stream completes before timeout
# Test 2: Stream times out if no elements
# Test 3: Timer resets with each element
# Test 4: Works with slow streams (elements with delays)
# Test 5: Error message includes timeout value
```

## Task 4: Update Stream Class

Add the three new methods to `lib/grey/static/stream/Stream.pm`:

```perl
method throttle ($min_delay, $executor) {
    Stream::Operation::Throttle->new(
        source => $self,
        min_delay => $min_delay,
        executor => $executor
    );
}

method debounce ($quiet_delay, $executor) {
    Stream::Operation::Debounce->new(
        source => $self,
        min_delay => $quiet_delay,
        executor => $executor
    );
}

method timeout ($timeout_delay, $executor) {
    Stream::Operation::Timeout->new(
        source => $self,
        timeout_delay => $timeout_delay,
        executor => $executor
    );
}
```

## Task 5: Update Feature Loader

Update `lib/grey/static/stream.pm` to load the new operations:

```perl
load_module('Stream::Operation::Throttle');
load_module('Stream::Operation::Debounce');
load_module('Stream::Operation::Timeout');
```

## Task 6: Create Comprehensive Tests

### Test File: `t/grey/static/02-stream/040-time-operations.t`

**Test Structure:**
```perl
#!/usr/bin/env perl
use v5.42;
use Test::More;

use grey::static qw[ functional stream concurrency::util ];

# Throttle tests (5-7 subtests)
subtest 'throttle - basic functionality' => sub { ... };
subtest 'throttle - first element immediate' => sub { ... };
subtest 'throttle - drops rapid elements' => sub { ... };
subtest 'throttle - allows after min_delay' => sub { ... };
subtest 'throttle - with executor time advancement' => sub { ... };

# Debounce tests (5-7 subtests)
subtest 'debounce - single element' => sub { ... };
subtest 'debounce - rapid elements emit last' => sub { ... };
subtest 'debounce - multiple quiet periods' => sub { ... };
subtest 'debounce - stream end triggers emission' => sub { ... };
subtest 'debounce - with time advancement' => sub { ... };

# Timeout tests (5-7 subtests)
subtest 'timeout - completes before timeout' => sub { ... };
subtest 'timeout - times out with no elements' => sub { ... };
subtest 'timeout - timer resets per element' => sub { ... };
subtest 'timeout - error message format' => sub { ... };
subtest 'timeout - with slow streams' => sub { ... };

# Integration tests (3-5 subtests)
subtest 'chaining time operations' => sub { ... };
subtest 'time operations with other operations' => sub { ... };
subtest 'multiple executors' => sub { ... };

done_testing;
```

### Example Test

```perl
subtest 'throttle - drops rapid elements' => sub {
    my $executor = ScheduledExecutor->new;

    # Create stream that produces elements at specific times
    my @values;
    my $source = Stream->from_array([1, 2, 3, 4, 5]);

    # Throttle with min_delay of 10 ticks
    my $throttled = $source->throttle(10, $executor);

    # Simulate element consumption with time advancement
    push @values, $throttled->next;  # t=0, value=1 (first, passes)

    $executor->schedule_delayed(sub {}, 5);  # Advance to t=5
    $executor->run;

    push @values, $throttled->next if $throttled->has_next;  # t=5, value=2 (dropped, < 10 ticks)

    $executor->schedule_delayed(sub {}, 5);  # Advance to t=10
    $executor->run;

    push @values, $throttled->next if $throttled->has_next;  # t=10, value=3 (passes, >= 10 ticks)

    is_deeply(\@values, [1, 3], 'rapid elements dropped');
};
```

**Note:** The test pattern requires careful orchestration of executor time advancement. Consider using a helper function to advance time between stream operations.

## Implementation Notes

### Challenge: Pull-Based Streams vs. Time-Based Operations

Streams are **pull-based** (consumer calls `next()`), but time-based operations need **temporal control**. Solutions:

1. **Throttle:** Check time on pull, skip elements that are too soon
2. **Debounce:** Buffer elements and check elapsed time on pull
3. **Timeout:** Check elapsed time on each `has_next()` call

The executor's `current_time` provides the time reference. Tests must explicitly advance time using `schedule_delayed()` and `run()`.

### Time Advancement in Tests

```perl
# Helper function for tests
sub advance_time($executor, $delta) {
    $executor->schedule_delayed(sub {}, $delta);
    $executor->run;
}

# Usage
advance_time($executor, 10);  # Advance 10 ticks
my $value = $stream->next;    # Pull element at new time
```

### Error Handling

- Timeout should throw grey::static::error Error
- Throttle and Debounce should not throw errors for timing, only for stream exhaustion
- All operations should propagate source stream errors

### Integration with Existing Operations

Time operations should compose cleanly with existing operations:

```perl
Stream->from_array([1, 2, 3, 4, 5])
    ->map(sub { $_ * 2 })
    ->throttle(10, $executor)
    ->filter(sub { $_ > 5 })
    ->timeout(50, $executor)
    ->to_array;
```

## Success Criteria

✅ All three operations implemented and following Stream::Operation pattern
✅ Methods added to Stream class
✅ Feature loader updated
✅ Comprehensive test file with 15+ tests
✅ All tests passing
✅ No regressions in existing stream tests (40+ tests)
✅ Full test suite still passing (924+ tests)
✅ Integration tests showing operations working together

## Expected Outcomes

**New Files:**
- `lib/grey/static/stream/Stream/Operation/Throttle.pm`
- `lib/grey/static/stream/Stream/Operation/Debounce.pm`
- `lib/grey/static/stream/Stream/Operation/Timeout.pm`
- `t/grey/static/02-stream/040-time-operations.t`

**Modified Files:**
- `lib/grey/static/stream/Stream.pm` - Add throttle(), debounce(), timeout() methods
- `lib/grey/static/stream.pm` - Load new operation classes

**Test Results:**
- Stream time operations: 15-20 new tests
- Existing stream tests: Still passing
- Full test suite: Still passing

## Reference Materials

**Study these existing stream operations for patterns:**
- `lib/grey/static/stream/Stream/Operation/Map.pm` - Simple transformation
- `lib/grey/static/stream/Stream/Operation/Filter.pm` - Conditional pass-through
- `lib/grey/static/stream/Stream/Operation/Take.pm` - Stateful limiting

**Key files to understand:**
- `lib/grey/static/stream/Stream.pm` - Main Stream class
- `lib/grey/static/stream/Stream/Operation.pm` - Base operation class
- `lib/grey/static/concurrency/util/ScheduledExecutor.pm` - Time advancement
- `t/grey/static/02-stream/001-basic.t` - Stream testing patterns

## Tips for Implementation

1. **Start with Throttle** - Simplest of the three operations
2. **Test incrementally** - Write tests as you implement each operation
3. **Use DEBUG output** - Add temporary debug output to understand timing
4. **Consider edge cases** - Empty streams, single elements, timing boundaries
5. **Verify no regressions** - Run full stream test suite after each operation

## Next Steps After Completion

After Stream Time Operations are working:
1. Update `docs/TIMER_INTEGRATION_STATUS.md` to mark as complete
2. Consider adding POD documentation to new operations
3. Optionally create example demonstrating reactive stream patterns
4. Move to Priority 4: Documentation & Examples

Good luck! The foundation is solid - now add temporal superpowers to streams! 🚀
