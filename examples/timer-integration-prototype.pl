#!/usr/bin/env perl
#
# Prototype: ScheduledExecutor - Executor + Timer::Wheel integration
#
# This shows how Timer::Wheel could power a time-aware event loop
# that enables Promise timeouts, delayed execution, and intervals.

use v5.42;
use experimental qw[ class try ];

use lib 'lib';
use grey::static qw[ time::wheel concurrency::util ];

# Prototype ScheduledExecutor combining Executor + Timer::Wheel
class ScheduledExecutor :isa(Executor) {
    field $wheel = Timer::Wheel->new;
    field $current_time = 0;
    field $next_timer_id = 1;
    field %active_timers;  # timer_id => Timer mapping

    # Schedule callback with delay
    method schedule_delayed($callback, $delay_ticks) {
        my $timer_id = $next_timer_id++;
        my $expiry = $current_time + $delay_ticks;

        my $timer = Timer->new(
            id     => $timer_id,
            expiry => $expiry,
            event  => sub {
                delete $active_timers{$timer_id};
                $self->next_tick($callback);
            }
        );

        $wheel->add_timer($timer);
        $active_timers{$timer_id} = $timer;

        return $timer_id;
    }

    # Get current time
    method current_time { $current_time }

    # Override run() to advance time automatically
    method run {
        while (!$self->is_done || $wheel->timer_count > 0) {
            # Find next timer
            my $next_timeout = $wheel->find_next_timeout;

            if (defined $next_timeout && $next_timeout > $current_time) {
                # Advance to next timer
                my $delta = $next_timeout - $current_time;
                $wheel->advance_by($delta);
                $current_time = $next_timeout;
            }

            # Run executor tick (processes callbacks that timers added)
            $self->tick;

            # If nothing to do and no timers, we're done
            last if $self->is_done && $wheel->timer_count == 0;
        }
    }
}

# Add timeout() method to Promise (monkey patch for demo)
{
    no warnings 'redefine';
    my $original_new = \&Promise::new;

    *Promise::timeout = sub ($self, $ms, $executor) {
        my $timeout_promise = Promise->new(executor => $executor);

        my $timer_id = $executor->schedule_delayed(
            sub {
                $timeout_promise->reject("Timeout after ${ms}ms");
            },
            $ms
        );

        $self->then(
            sub ($value) {
                # Success - no need to cancel, will be ignored
                $timeout_promise->resolve($value);
            },
            sub ($error) {
                # Failure
                $timeout_promise->reject($error);
            }
        );

        return $timeout_promise;
    };
}

say "=" x 70;
say "ScheduledExecutor Prototype Demo";
say "=" x 70;
say "";

# Demo 1: Basic delayed execution
say "=== Demo 1: Delayed Execution ===";
{
    my $executor = ScheduledExecutor->new;

    say "Scheduling tasks at t=0";

    $executor->schedule_delayed(sub { say "  Task 1 executed at t=10" }, 10);
    $executor->schedule_delayed(sub { say "  Task 2 executed at t=20" }, 20);
    $executor->schedule_delayed(sub { say "  Task 3 executed at t=5" }, 5);

    say "Running executor...";
    $executor->run;
    say "Done!";
}
say "";

# Demo 2: Promise with delay
say "=== Demo 2: Promise Delayed Resolution ===";
{
    my $executor = ScheduledExecutor->new;

    my $p1 = Promise->new(executor => $executor);

    $p1->then(sub ($x) { say "  Promise resolved with: $x" });

    # Resolve after 15 ticks
    $executor->schedule_delayed(
        sub { $p1->resolve("Hello after 15 ticks!") },
        15
    );

    say "Running executor...";
    $executor->run;
    say "Done!";
}
say "";

# Demo 3: Promise timeout (success case)
say "=== Demo 3: Promise Timeout (Success) ===";
{
    my $executor = ScheduledExecutor->new;

    my $p1 = Promise->new(executor => $executor);

    # Add timeout of 100 ticks
    $p1->timeout(100, $executor)
        ->then(
            sub ($x) { say "  Success: $x" },
            sub ($e) { say "  Failed: $e" }
        );

    # Resolve after 50 ticks (before timeout)
    $executor->schedule_delayed(
        sub { $p1->resolve("Completed in time!") },
        50
    );

    say "Running executor...";
    $executor->run;
    say "Done!";
}
say "";

# Demo 4: Promise timeout (timeout case)
say "=== Demo 4: Promise Timeout (Timeout) ===";
{
    my $executor = ScheduledExecutor->new;

    my $p1 = Promise->new(executor => $executor);

    # Add timeout of 30 ticks
    $p1->timeout(30, $executor)
        ->then(
            sub ($x) { say "  Success: $x" },
            sub ($e) { say "  Failed: $e" }
        );

    # Resolve after 50 ticks (after timeout)
    $executor->schedule_delayed(
        sub { $p1->resolve("Too late!") },
        50
    );

    say "Running executor...";
    $executor->run;
    say "Done!";
}
say "";

# Demo 5: Chained promises with timeouts
say "=== Demo 5: Promise Chain with Timeouts ===";
{
    my $executor = ScheduledExecutor->new;

    my $fetch_user = sub ($id) {
        my $p = Promise->new(executor => $executor);
        $executor->schedule_delayed(
            sub { $p->resolve("User_$id") },
            10  # Simulate 10ms fetch
        );
        return $p->timeout(20, $executor);  # 20ms timeout
    };

    my $fetch_posts = sub ($user) {
        my $p = Promise->new(executor => $executor);
        $executor->schedule_delayed(
            sub { $p->resolve(["Post1", "Post2"]) },
            15  # Simulate 15ms fetch
        );
        return $p->timeout(25, $executor);  # 25ms timeout
    };

    $fetch_user->(123)
        ->then($fetch_posts)
        ->then(
            sub ($posts) { say "  Got posts: ", join(", ", @$posts) },
            sub ($err)   { say "  Chain failed: $err" }
        );

    say "Running executor...";
    $executor->run;
    say "Done!";
}
say "";

say "=" x 70;
say "Prototype demonstrates:";
say "  - Delayed execution (schedule_delayed)";
say "  - Promise timeouts";
say "  - Automatic time advancement";
say "  - Integration of Timer::Wheel + Executor + Promise";
say "";
say "This could enable:";
say "  - Stream throttling/debouncing";
say "  - Flow timeouts";
say "  - Scheduled intervals";
say "  - Real-time event loops";
say "=" x 70;
