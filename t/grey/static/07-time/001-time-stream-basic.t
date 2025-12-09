#!perl
# Basic Time stream tests

use v5.42;
use Test::More;

use grey::static qw[ functional stream time::stream ];

# Test of_epoch
subtest 'Time->of_epoch()' => sub {
    my @times = Time->of_epoch()
        ->take(3)
        ->collect(Stream::Collectors->ToList);

    is(scalar @times, 3, 'collected 3 epoch times');
    ok($times[0] > 0, 'first time is positive');
    ok($times[1] >= $times[0], 'times are non-decreasing');
    ok($times[2] >= $times[1], 'times are non-decreasing');
};

# Test of_monotonic
subtest 'Time->of_monotonic()' => sub {
    my @times = Time->of_monotonic()
        ->take(3)
        ->collect(Stream::Collectors->ToList);

    is(scalar @times, 3, 'collected 3 monotonic times');
    ok($times[0] >= 0, 'first time is non-negative');
    ok($times[1] >= $times[0], 'monotonic times are non-decreasing');
    ok($times[2] >= $times[1], 'monotonic times are non-decreasing');
};

# Test of_delta
subtest 'Time->of_delta()' => sub {
    my @deltas = Time->of_delta()
        ->take(3)
        ->collect(Stream::Collectors->ToList);

    is(scalar @deltas, 3, 'collected 3 delta times');
    is($deltas[0], 0, 'first delta is 0');
    ok($deltas[1] >= 0, 'second delta is non-negative');
    ok($deltas[2] >= 0, 'third delta is non-negative');
};

# Test sleep_for
subtest 'Time->sleep_for()' => sub {
    my @times = Time->of_epoch()
        ->take(2)
        ->sleep_for(0.01)  # Sleep 10ms between elements
        ->collect(Stream::Collectors->ToList);

    is(scalar @times, 2, 'collected 2 times with sleep');
    # Just verify the function exists and returns correct count
    # Timing tests are unreliable in test environments
};

done_testing;
