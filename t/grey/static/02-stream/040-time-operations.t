#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream concurrency::util ];

# Helper function to advance executor time
sub advance_time($executor, $delta) {
    $executor->schedule_delayed(sub {}, $delta);
    $executor->run;
}

## -------------------------------------------------------------------------
## Throttle Tests
## -------------------------------------------------------------------------

subtest 'throttle - first element passes immediately' => sub {
    my $executor = ScheduledExecutor->new;

    my $start = $executor->current_time;
    my @result = Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor)
        ->take(1)
        ->collect(Stream::Collectors->ToList);

    my $elapsed = $executor->current_time - $start;
    is_deeply(\@result, [1], 'first element passes immediately');
    cmp_ok($elapsed, '<', 5, 'minimal time elapsed');
};

subtest 'throttle - rapid pulls are blocked' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor);

    my @result;

    # First element passes at t=0
    push @result, $stream->source->next if $stream->source->has_next;

    # Try to pull immediately - should be blocked
    ok(!$stream->source->has_next, 'second element blocked at t=0');

    # Advance time by 5ms
    advance_time($executor, 5);

    # Still blocked (need >= 10ms)
    ok(!$stream->source->has_next, 'second element still blocked at t=5');

    # Advance to t=10
    advance_time($executor, 5);

    # Now it should pass
    ok($stream->source->has_next, 'second element available at t=10');
    push @result, $stream->source->next;

    is_deeply(\@result, [1, 2], 'throttle allows elements at proper intervals');
};

subtest 'throttle - multiple elements with time advancement' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor);

    my @result;

    # Manually pull with time advancement - use slightly longer delay for real-time reliability
    for (1 .. 3) {
        if ($stream->source->has_next) {
            push @result, $stream->source->next;
        }
        advance_time($executor, 12);
    }

    is_deeply(\@result, [1, 2, 3], 'throttle emits elements at 10ms intervals');
};

subtest 'throttle - with min_delay of 0' => sub {
    my $executor = ScheduledExecutor->new;

    my @result = Stream->of(1, 2, 3, 4, 5)
        ->throttle(0, $executor)
        ->collect(Stream::Collectors->ToList);

    is_deeply(\@result, [1, 2, 3, 4, 5], 'throttle with 0 delay passes all elements');
};

subtest 'throttle - empty stream' => sub {
    my $executor = ScheduledExecutor->new;

    my @result = Stream->of()
        ->throttle(10, $executor)
        ->collect(Stream::Collectors->ToList);

    is_deeply(\@result, [], 'throttle handles empty stream');
};

## -------------------------------------------------------------------------
## Debounce Tests
## -------------------------------------------------------------------------

subtest 'debounce - single element emits after quiet period' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1)
        ->debounce(10, $executor);

    # Element is buffered, not yet available
    ok(!$stream->source->has_next, 'element not available immediately');

    # Advance time to trigger quiet period
    advance_time($executor, 10);

    # Now element should be available
    ok($stream->source->has_next, 'element available after quiet period');

    my @result;
    push @result, $stream->source->next;

    is_deeply(\@result, [1], 'single element emitted after quiet period');
};

subtest 'debounce - rapid elements emit only last' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->debounce(10, $executor);

    # All elements consumed immediately into buffer
    # Only last one should be emitted after quiet period
    ok(!$stream->source->has_next, 'no elements available immediately');

    # Advance past quiet period
    advance_time($executor, 10);

    ok($stream->source->has_next, 'element available after quiet period');

    my @result;
    push @result, $stream->source->next if $stream->source->has_next;

    is_deeply(\@result, [5], 'only last element emitted after debounce');
};

subtest 'debounce - with quiet_delay of 0' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3)
        ->debounce(0, $executor);

    # With 0 delay, should emit immediately after source exhaustion
    ok($stream->source->has_next, 'element available with 0 delay');

    my @result;
    push @result, $stream->source->next if $stream->source->has_next;

    is_deeply(\@result, [3], 'last element emitted with 0 delay');
};

subtest 'debounce - empty stream' => sub {
    my $executor = ScheduledExecutor->new;

    my @result = Stream->of()
        ->debounce(10, $executor)
        ->collect(Stream::Collectors->ToList);

    is_deeply(\@result, [], 'debounce handles empty stream');
};

subtest 'debounce - multiple quiet periods' => sub {
    my $executor = ScheduledExecutor->new;

    # Create a stream that we'll manually control
    my @values = (1, 2, 3);
    my $idx = 0;
    my $stream = Stream->generate(sub {
        return undef if $idx >= @values;
        return $values[$idx++];
    })
        ->take(3)
        ->debounce(10, $executor);

    # Pull to buffer elements (debounce is pull-based)
    $stream->source->has_next;

    # Wait for quiet period - use longer delay for reliability with real time
    advance_time($executor, 15);

    my @result;
    push @result, $stream->source->next if $stream->source->has_next;

    is_deeply(\@result, [3], 'debounce emits last value after quiet period');
};

## -------------------------------------------------------------------------
## Timeout Tests
## -------------------------------------------------------------------------

subtest 'timeout - completes before timeout' => sub {
    my $executor = ScheduledExecutor->new;

    my @result = Stream->of(1, 2, 3)
        ->timeout(100, $executor)
        ->collect(Stream::Collectors->ToList);

    is_deeply(\@result, [1, 2, 3], 'stream completes before timeout');
};

subtest 'timeout - times out with no elements' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of()
        ->timeout(10, $executor);

    # Advance time past timeout
    advance_time($executor, 10);

    eval {
        $stream->source->has_next;
    };

    ok($@, 'timeout throws error');
    like("$@", qr/Stream timeout/, 'error message mentions timeout');
    like("$@", qr/10\s*ms/, 'error message includes timeout value');
};

subtest 'timeout - timer resets with each element' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3)
        ->timeout(10, $executor);

    my @result;

    # Pull first element
    push @result, $stream->source->next if $stream->source->has_next;

    # Advance time but stay under timeout
    advance_time($executor, 5);

    # Pull second element (resets timer)
    push @result, $stream->source->next if $stream->source->has_next;

    # Advance time but stay under timeout
    advance_time($executor, 5);

    # Pull third element
    push @result, $stream->source->next if $stream->source->has_next;

    is_deeply(\@result, [1, 2, 3], 'timer resets with each element');
};

subtest 'timeout - times out between elements' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3)
        ->timeout(10, $executor);

    my @result;

    # Pull first element
    push @result, $stream->source->next if $stream->source->has_next;

    # Advance past timeout
    advance_time($executor, 15);

    eval {
        $stream->source->has_next;
    };

    ok($@, 'timeout occurs between elements');
    like("$@", qr/Stream timeout/, 'error message correct');
};

subtest 'timeout - zero timeout' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3)
        ->timeout(0, $executor);

    eval {
        $stream->source->has_next;
    };

    ok($@, 'zero timeout triggers immediately');
};

## -------------------------------------------------------------------------
## Integration Tests
## -------------------------------------------------------------------------

subtest 'integration - throttle with map' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->map(sub ($x) { $x * 2 })
        ->throttle(10, $executor);

    my @result;

    # Pull elements with time advancement
    for (1 .. 3) {
        if ($stream->source->has_next) {
            push @result, $stream->source->next;
        }
        advance_time($executor, 10);
    }

    is_deeply(\@result, [2, 4, 6], 'throttle works with map');
};

subtest 'integration - throttle with grep' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5, 6)
        ->grep(sub ($x) { $x % 2 == 0 })
        ->throttle(10, $executor);

    my @result;

    # Pull elements with time advancement
    for (1 .. 2) {
        if ($stream->source->has_next) {
            push @result, $stream->source->next;
        }
        advance_time($executor, 10);
    }

    is_deeply(\@result, [2, 4], 'throttle works with grep');
};

subtest 'integration - debounce with map' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->map(sub ($x) { $x * 2 })
        ->debounce(10, $executor);

    # Pull to buffer elements (debounce is pull-based)
    $stream->source->has_next;

    advance_time($executor, 10);

    my @result;
    push @result, $stream->source->next if $stream->source->has_next;

    is_deeply(\@result, [10], 'debounce works with map');
};

subtest 'integration - timeout with slow operations' => sub {
    my $executor = ScheduledExecutor->new;

    # This should complete without timeout
    my @result = Stream->of(1, 2, 3)
        ->map(sub ($x) { $x * 2 })
        ->timeout(100, $executor)
        ->collect(Stream::Collectors->ToList);

    is_deeply(\@result, [2, 4, 6], 'timeout works with map operations');
};

subtest 'integration - chaining time operations' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor)
        ->timeout(50, $executor);

    my @result;

    # Pull with time advancement - use longer delays for real-time reliability
    for (1 .. 3) {
        if ($stream->source->has_next) {
            push @result, $stream->source->next;
        }
        advance_time($executor, 12);
    }

    is_deeply(\@result, [1, 2, 3], 'can chain throttle and timeout');
};

subtest 'integration - time operations with take' => sub {
    my $executor = ScheduledExecutor->new;

    my $stream = Stream->of(1, 2, 3, 4, 5)
        ->throttle(10, $executor)
        ->take(2);

    my @result;

    # Pull first
    push @result, $stream->source->next if $stream->source->has_next;

    # Advance and pull second
    advance_time($executor, 10);
    push @result, $stream->source->next if $stream->source->has_next;

    is_deeply(\@result, [1, 2], 'time operations work with take');
};

done_testing;
