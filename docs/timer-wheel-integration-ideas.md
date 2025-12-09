# Timer::Wheel Integration & Enhancement Ideas

## Current Limitations

1. **No cancellation** - Timers can't be cancelled once added
2. **One-shot only** - No recurring/interval timers
3. **No event loop** - Manual `advance_by()` required
4. **Isolated** - No integration with Executor, Promise, or Flow
5. **Absolute time only** - No relative delays

## Enhancement Ideas

### 1. Timer Improvements

**Add Timer IDs for cancellation:**
```perl
class Timer {
    field $id     :param :reader;  # Unique ID
    field $expiry :param :reader;
    field $event  :param :reader;
    field $recurring :param :reader = 0;  # Interval for recurring
}

# Timer::Wheel additions
method cancel_timer($id) {
    # Remove timer by ID from wheel
}
```

**Add recurring timers:**
```perl
my $timer = Timer->new(
    expiry    => 100,
    recurring => 50,  # Fire every 50 ticks
    event     => sub { say "Tick!" }
);
```

### 2. ScheduledExecutor (Executor + Timer::Wheel)

**Combine Executor with Timer::Wheel for time-aware async:**

```perl
class ScheduledExecutor :isa(Executor) {
    field $wheel = Timer::Wheel->new;
    field $current_time = 0;

    # Schedule callback with delay
    method schedule_delayed($callback, $delay_ms) {
        my $expiry = $current_time + $delay_ms;
        my $timer = Timer->new(
            expiry => $expiry,
            event  => sub { $self->next_tick($callback) }
        );
        $wheel->add_timer($timer);
        return $timer->id;
    }

    # Schedule recurring callback
    method schedule_interval($callback, $interval_ms) {
        my $timer = Timer->new(
            expiry    => $current_time + $interval_ms,
            recurring => $interval_ms,
            event     => sub { $self->next_tick($callback) }
        );
        $wheel->add_timer($timer);
        return $timer->id;
    }

    # Cancel scheduled callback
    method cancel_scheduled($timer_id) {
        $wheel->cancel_timer($timer_id);
    }

    # Override run() to advance time
    method run {
        while (!$self->is_done || $wheel->timer_count > 0) {
            # Advance wheel to next timer
            my $next_timeout = $wheel->find_next_timeout;
            if (defined $next_timeout) {
                my $delta = $next_timeout - $current_time;
                $wheel->advance_by($delta);
                $current_time = $next_timeout;
            }

            # Run executor tick
            $self->tick;
        }
    }
}
```

**Usage:**
```perl
my $executor = ScheduledExecutor->new;

# Delayed execution
$executor->schedule_delayed(sub { say "After 1 second" }, 1000);

# Recurring execution
my $interval_id = $executor->schedule_interval(
    sub { say "Every 500ms" },
    500
);

# Cancel recurring timer
$executor->cancel_scheduled($interval_id);

$executor->run;
```

### 3. Promise Timeout Support

**Add timeout to Promise:**

```perl
# In Promise class
method timeout($ms, $executor) {
    my $timeout_promise = Promise->new(executor => $executor);

    my $timer_id = $executor->schedule_delayed(
        sub { $timeout_promise->reject("Timeout after ${ms}ms") },
        $ms
    );

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

# Promise::delay factory
sub Promise::delay($class, $value, $ms, $executor) {
    my $p = Promise->new(executor => $executor);

    $executor->schedule_delayed(
        sub { $p->resolve($value) },
        $ms
    );

    return $p;
}
```

**Usage:**
```perl
my $executor = ScheduledExecutor->new;

# Timeout example
my $promise = fetch_data()
    ->timeout(5000, $executor)
    ->then(
        sub ($data) { say "Got: $data" },
        sub ($err)  { say "Failed: $err" }
    );

# Delay example
Promise->delay("Hello", 1000, $executor)
    ->then(sub ($msg) { say $msg });

$executor->run;
```

### 4. Stream Time Operations

**Add time-based stream operations:**

```perl
class Stream::Operation::Throttle :isa(Stream::Operation) {
    field $min_interval_ms :param;
    field $executor        :param;

    field $last_emit_time = 0;

    method on_next($element) {
        my $now = $executor->current_time;

        if ($now - $last_emit_time >= $min_interval_ms) {
            $last_emit_time = $now;
            $self->emit($element);
        }
        # else: drop element (too soon)
    }
}

class Stream::Operation::Debounce :isa(Stream::Operation) {
    field $delay_ms  :param;
    field $executor  :param;

    field $pending_timer_id;
    field $pending_value;

    method on_next($element) {
        # Cancel previous timer
        $executor->cancel_scheduled($pending_timer_id)
            if defined $pending_timer_id;

        $pending_value = $element;
        $pending_timer_id = $executor->schedule_delayed(
            sub {
                $self->emit($pending_value);
                $pending_timer_id = undef;
            },
            $delay_ms
        );
    }
}

class Stream::Operation::Timeout :isa(Stream::Operation) {
    field $timeout_ms :param;
    field $executor   :param;

    field $timeout_timer_id;

    method on_subscribe($subscription) {
        # Start timeout
        $timeout_timer_id = $executor->schedule_delayed(
            sub { $self->on_error("Stream timeout after ${timeout_ms}ms") },
            $timeout_ms
        );
    }

    method on_next($element) {
        # Reset timeout on each element
        $executor->cancel_scheduled($timeout_timer_id);
        $timeout_timer_id = $executor->schedule_delayed(
            sub { $self->on_error("Stream timeout after ${timeout_ms}ms") },
            $timeout_ms
        );

        $self->emit($element);
    }
}
```

**Usage:**
```perl
my $executor = ScheduledExecutor->new;

# Throttle: max 1 element per second
Stream->of(1..100)
    ->throttle(1000, $executor)
    ->collect(Stream::Collectors->ToList);

# Debounce: wait 500ms after last element
$user_input_stream
    ->debounce(500, $executor)
    ->map(sub { search($_[0]) })
    ->collect(...);

# Timeout: fail if no element within 5 seconds
$network_stream
    ->timeout(5000, $executor)
    ->collect(...);
```

### 5. Flow Timeout Support

**Add timeout to reactive Flow:**

```perl
class Flow::Operation::Timeout :isa(Flow::Operation) {
    field $timeout_ms :param;
    field $executor   :param;

    field $timeout_timer_id;

    method on_subscribe($subscription) {
        $timeout_timer_id = $executor->schedule_delayed(
            sub {
                $subscription->cancel();
                $self->subscriber->on_error("Flow timeout");
            },
            $timeout_ms
        );
    }

    method on_next($element) {
        # Reset timeout
        $executor->cancel_scheduled($timeout_timer_id);
        $timeout_timer_id = $executor->schedule_delayed(
            sub { $self->subscriber->on_error("Flow timeout") },
            $timeout_ms
        );

        # Forward element
        $self->subscriber->on_next($element);
    }
}
```

### 6. Real-time Clock Integration

**Add wall-clock time support:**

```perl
class RealtimeScheduledExecutor :isa(ScheduledExecutor) {
    use Time::HiRes qw(time);

    field $start_time = time();

    method schedule_at($callback, $unix_timestamp) {
        my $delay_ms = int(($unix_timestamp - time()) * 1000);
        return $self->schedule_delayed($callback, $delay_ms);
    }

    method run {
        while (!$self->is_done || $wheel->timer_count > 0) {
            my $next_timeout = $wheel->find_next_timeout;

            if (defined $next_timeout) {
                # Sleep until next timer
                my $sleep_ms = $next_timeout - $current_time;
                Time::HiRes::usleep($sleep_ms * 1000) if $sleep_ms > 0;

                $current_time = int((time() - $start_time) * 1000);
                $wheel->advance_by($current_time);
            }

            $self->tick;
        }
    }
}
```

## Implementation Priority

### High Value (Quick Wins)
1. **ScheduledExecutor** - Enables all other features
2. **Promise->timeout()** - Common use case
3. **Promise->delay()** - Common use case
4. **Timer cancellation** - Required for timeout

### Medium Value
5. **Stream::Operation::Throttle** - Rate limiting is useful
6. **Stream::Operation::Debounce** - UI/search use cases
7. **Recurring timers** - setInterval equivalent

### Lower Priority
8. **Stream::Operation::Timeout** - Less common
9. **Flow timeout** - Specialized use case
10. **Real-time integration** - Can be external

## Benefits

**Code reuse:**
- Timer::Wheel becomes foundation for all time-based features
- One timing mechanism instead of ad-hoc solutions

**Performance:**
- O(1) timer operations at any scale
- Efficient event loop with minimal overhead

**Composability:**
- Time-aware Promises
- Time-aware Streams
- Time-aware Flow

**New capabilities:**
- Scheduled async execution
- Rate limiting
- Debouncing
- Timeouts everywhere

## Questions for Discussion

1. Should ScheduledExecutor be the default Executor?
2. Should time be tick-based (abstract) or ms-based (real)?
3. Should Timer cancellation return boolean (found/not found)?
4. Should recurring timers auto-cancel on error?
5. Should we add Timer::Wheel::State->now() for current time?
