#!/usr/bin/env perl
# Test Timer::Wheel cancellation functionality

use v5.42;
use Test::More;

use grey::static qw[ time::wheel ];

# Test cancel before firing
subtest 'cancel timer before it fires' => sub {
    my $wheel = Timer::Wheel->new;
    my $fired = 0;

    $wheel->add_timer(Timer->new(
        id     => 'timer1',
        expiry => 10,
        event  => sub { $fired = 1 }
    ));

    is($wheel->timer_count, 1, 'wheel has 1 timer');

    # Cancel the timer
    my $cancelled = $wheel->cancel_timer('timer1');
    is($cancelled, 1, 'cancel_timer returns 1 for success');
    is($wheel->timer_count, 0, 'wheel has 0 timers after cancellation');

    # Advance past the expiry time
    $wheel->advance_by(15);
    is($fired, 0, 'cancelled timer did not fire');
};

# Test cancel non-existent timer
subtest 'cancel non-existent timer' => sub {
    my $wheel = Timer::Wheel->new;

    my $cancelled = $wheel->cancel_timer('does-not-exist');
    is($cancelled, 0, 'cancel_timer returns 0 for non-existent timer');
};

# Test cancel after firing
subtest 'cancel timer after it fires' => sub {
    my $wheel = Timer::Wheel->new;
    my $fired = 0;

    $wheel->add_timer(Timer->new(
        id     => 'timer2',
        expiry => 5,
        event  => sub { $fired = 1 }
    ));

    # Advance to fire the timer
    $wheel->advance_by(5);
    is($fired, 1, 'timer fired');
    is($wheel->timer_count, 0, 'timer removed from wheel after firing');

    # Try to cancel already-fired timer
    my $cancelled = $wheel->cancel_timer('timer2');
    is($cancelled, 0, 'cancel_timer returns 0 for already-fired timer');
};

# Test cancel one of multiple timers
subtest 'cancel one timer among many' => sub {
    my @fired;
    my $wheel = Timer::Wheel->new;

    $wheel->add_timer(Timer->new(id => 'A', expiry => 5,  event => sub { push @fired, 'A' }));
    $wheel->add_timer(Timer->new(id => 'B', expiry => 10, event => sub { push @fired, 'B' }));
    $wheel->add_timer(Timer->new(id => 'C', expiry => 15, event => sub { push @fired, 'C' }));

    is($wheel->timer_count, 3, 'wheel has 3 timers');

    # Cancel middle timer
    $wheel->cancel_timer('B');
    is($wheel->timer_count, 2, 'wheel has 2 timers after cancellation');

    # Advance to fire all timers
    $wheel->advance_by(20);
    is_deeply(\@fired, ['A', 'C'], 'only non-cancelled timers fired');
};

# Test cancel timer in different bucket
subtest 'cancel timer in higher depth bucket' => sub {
    my $wheel = Timer::Wheel->new;
    my $fired = 0;

    $wheel->add_timer(Timer->new(
        id     => 'large',
        expiry => 500,
        event  => sub { $fired = 1 }
    ));

    is($wheel->timer_count, 1, 'wheel has 1 timer');

    # Cancel the timer
    my $cancelled = $wheel->cancel_timer('large');
    is($cancelled, 1, 'cancel_timer returns 1 for success');
    is($wheel->timer_count, 0, 'wheel has 0 timers after cancellation');

    # Advance past the expiry time
    $wheel->advance_by(600);
    is($fired, 0, 'cancelled timer did not fire');
};

# Test cancel timer after it moves between buckets
subtest 'cancel timer that has moved buckets' => sub {
    my $wheel = Timer::Wheel->new;
    my $fired = 0;

    $wheel->add_timer(Timer->new(
        id     => 'mover',
        expiry => 150,
        event  => sub { $fired = 1 }
    ));

    is($wheel->timer_count, 1, 'wheel has 1 timer');

    # Advance partially (this may cause the timer to move to a different bucket)
    $wheel->advance_by(100);
    is($wheel->timer_count, 1, 'timer still in wheel after partial advance');
    is($fired, 0, 'timer not yet fired');

    # Cancel the timer
    my $cancelled = $wheel->cancel_timer('mover');
    is($cancelled, 1, 'cancel_timer returns 1 for success');
    is($wheel->timer_count, 0, 'wheel has 0 timers after cancellation');

    # Advance past the expiry time
    $wheel->advance_by(100);
    is($fired, 0, 'cancelled timer did not fire');
};

# Test multiple cancellations
subtest 'cancel multiple timers' => sub {
    my $wheel = Timer::Wheel->new;
    my @fired;

    for my $i (1..10) {
        $wheel->add_timer(Timer->new(
            id     => "timer$i",
            expiry => $i * 10,
            event  => sub { push @fired, $i }
        ));
    }

    is($wheel->timer_count, 10, 'wheel has 10 timers');

    # Cancel even-numbered timers
    for my $i (2, 4, 6, 8, 10) {
        $wheel->cancel_timer("timer$i");
    }

    is($wheel->timer_count, 5, 'wheel has 5 timers after cancellations');

    # Advance to fire all remaining timers
    $wheel->advance_by(100);
    is_deeply(\@fired, [1, 3, 5, 7, 9], 'only non-cancelled timers fired');
};

done_testing;
