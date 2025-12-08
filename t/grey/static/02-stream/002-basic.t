#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '.... flatten test' => sub {
    my @results = Stream
        ->of(map { [0 .. 5] } 0 .. 5)
        ->flatten(sub ($a) { @$a })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(
        \@results,
        [ map { 0 .. 5 } 0 .. 5 ],
        '... got the expected flattened results'
    )
};

subtest '.... flat_map test' => sub {
    my @results = Stream
        ->of(map { [0 .. 5] } 0 .. 5)
        ->flat_map(sub ($a) { Stream->of( @$a ) })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(
        \@results,
        [ map { 0 .. 5 } 0 .. 5 ],
        '... got the expected flat mapped results'
    )
};

done_testing;
