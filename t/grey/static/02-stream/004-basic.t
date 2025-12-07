#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

my @results = Stream
->of( 1 .. 25 )
->gather(
    sub { [] },
    sub ($i, $acc) {
        push @$acc => $i;
        return true if scalar @$acc == 10;
        return false;
    },
)->collect( Stream::Collectors->ToList );

eq_or_diff(
    \@results,
    [
        [ 1  .. 10 ],
        [ 11 .. 20 ],
        [ 21 .. 25 ],
    ],
    '... got the expected gathered results'
);

done_testing;
