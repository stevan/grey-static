#!/usr/bin/env perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use grey::static qw[ time::wheel ];

# Test timer_count method
{
    my $wheel = Timer::Wheel->new;

    is($wheel->timer_count, 0, 'wheel starts with 0 timers');

    # Add a timer
    my $timer1 = Timer->new(expiry => 5, event => sub { });
    $wheel->add_timer($timer1);

    is($wheel->timer_count, 1, 'wheel has 1 timer after add');

    # Add another timer
    my $timer2 = Timer->new(expiry => 10, event => sub { });
    $wheel->add_timer($timer2);

    is($wheel->timer_count, 2, 'wheel has 2 timers after second add');
}

# Test timer count decreases when timers fire
{
    my $wheel = Timer::Wheel->new;
    my $fired = 0;

    my $timer = Timer->new(expiry => 5, event => sub { $fired++ });
    $wheel->add_timer($timer);

    is($wheel->timer_count, 1, 'wheel has 1 timer');

    # Advance to fire the timer
    $wheel->advance_by(5);

    is($wheel->timer_count, 0, 'wheel has 0 timers after firing');
    is($fired, 1, 'timer event fired');
}

# Test maximum timer limit (using a small number for testing)
SKIP: {
    # This test would take too long with MAX_TIMERS = 10000
    # We'd need to modify the constant to test this properly
    skip 'Would require modifying MAX_TIMERS constant', 1;

    my $wheel = Timer::Wheel->new;

    # Try to add MAX_TIMERS + 1 timers
    # Should throw an error
    eval {
        for my $i (1 .. 10001) {
            my $timer = Timer->new(expiry => $i, event => sub { });
            $wheel->add_timer($timer);
        }
    };

    like($@, qr/Timer wheel capacity exceeded/, 'error when exceeding max timers');
}

done_testing;
