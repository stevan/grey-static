#!perl
# Basic Timer::Wheel tests

use v5.42;
use Test::More;

use grey::static qw[ time::wheel ];

# Test Timer creation
subtest 'Timer construction' => sub {
    my $fired = 0;
    my $timer = Timer->new(
        expiry => 100,
        event  => sub { $fired = 1 }
    );

    isa_ok($timer, 'Timer');
    is($timer->expiry, 100, 'timer has correct expiry');
    is(ref $timer->event, 'CODE', 'timer has code ref event');

    $timer->event->();
    is($fired, 1, 'event callback executes');
};

# Test Timer::Wheel creation
subtest 'Timer::Wheel construction' => sub {
    my $wheel = Timer::Wheel->new;
    isa_ok($wheel, 'Timer::Wheel');
};

# Test basic timer firing
subtest 'basic timer firing' => sub {
    my $fired = 0;
    my $wheel = Timer::Wheel->new;

    $wheel->add_timer(Timer->new(
        expiry => 5,
        event  => sub { $fired = 1 }
    ));

    is($fired, 0, 'timer not yet fired');

    $wheel->advance_by(4);
    is($fired, 0, 'timer not yet fired after 4 ticks');

    $wheel->advance_by(1);
    is($fired, 1, 'timer fired after 5 ticks');
};

# Test multiple timers
subtest 'multiple timers' => sub {
    my @fired;
    my $wheel = Timer::Wheel->new;

    $wheel->add_timer(Timer->new(expiry => 5,  event => sub { push @fired, 'A' }));
    $wheel->add_timer(Timer->new(expiry => 10, event => sub { push @fired, 'B' }));
    $wheel->add_timer(Timer->new(expiry => 3,  event => sub { push @fired, 'C' }));

    $wheel->advance_by(3);
    is_deeply(\@fired, ['C'], 'first timer (3) fired');

    $wheel->advance_by(2);
    is_deeply(\@fired, ['C', 'A'], 'second timer (5) fired');

    $wheel->advance_by(5);
    is_deeply(\@fired, ['C', 'A', 'B'], 'third timer (10) fired');
};

# Test larger expiry times
subtest 'larger expiry times' => sub {
    my $fired = 0;
    my $wheel = Timer::Wheel->new;

    $wheel->add_timer(Timer->new(
        expiry => 100,
        event  => sub { $fired = 1 }
    ));

    $wheel->advance_by(99);
    is($fired, 0, 'timer not fired at 99');

    $wheel->advance_by(1);
    is($fired, 1, 'timer fired at 100');
};

done_testing;
