#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';

# Test loading via feature loader
use grey::static qw[ concurrency::actor ];

subtest 'Actor::Timer loaded via feature' => sub {
    ok(Actor::Timer->can('new'), '... Actor::Timer is loaded');

    # Verify we can also use concurrency::util alongside
    use grey::static qw[ concurrency::util ];

    my $executor = ScheduledExecutor->new;
    my $timer_id = $executor->schedule_delayed(sub { }, 100);

    my $timer = Actor::Timer->new(
        executor => $executor,
        timer_id => $timer_id
    );

    isa_ok($timer, 'Actor::Timer');
    ok(!$timer->cancelled, '... timer not cancelled');
    $timer->cancel;
    ok($timer->cancelled, '... timer cancelled');
};

done_testing;
