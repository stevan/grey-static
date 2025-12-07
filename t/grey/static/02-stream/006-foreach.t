#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... basic foreach' => sub {
    my @collected;

    Stream->of( 1 .. 10 )
        ->foreach(sub ($x) { push @collected => $x });

    eq_or_diff(\@collected, [1 .. 10], '... got the expected values');
};

subtest '... foreach with filtering' => sub {
    my @collected;

    Stream->of( 1 .. 10 )
        ->grep(sub ($x) { ($x % 2) == 0 })
        ->foreach(sub ($x) { push @collected => $x });

    eq_or_diff(\@collected, [2, 4, 6, 8, 10], '... got the expected even values');
};

subtest '... foreach with Consumer' => sub {
    my @collected;

    Stream->of( 1 .. 5 )
        ->foreach(Consumer->new( f => sub ($x) { push @collected => $x * 2 } ));

    eq_or_diff(\@collected, [2, 4, 6, 8, 10], '... got the expected doubled values');
};

subtest '... foreach with side effects' => sub {
    my $sum = 0;

    Stream->of( 1 .. 10 )
        ->foreach(sub ($x) { $sum += $x });

    is($sum, 55, '... side effect accumulated correctly');
};

done_testing;
