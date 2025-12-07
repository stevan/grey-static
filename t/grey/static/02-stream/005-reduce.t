#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

subtest '... basic reduce (sum)' => sub {
    my $sum = Stream->of( 1 .. 10 )
        ->reduce(0, sub ($acc, $x) { $acc + $x });

    is($sum, 55, '... got the expected sum');
};

subtest '... reduce (product)' => sub {
    my $product = Stream->of( 1 .. 5 )
        ->reduce(1, sub ($acc, $x) { $acc * $x });

    is($product, 120, '... got the expected product (5!)');
};

subtest '... reduce (concatenation)' => sub {
    # Note: reduce applies as reducer->apply($value, $accumulator)
    my $concat = Stream->of( 'a' .. 'e' )
        ->reduce('', sub ($x, $acc) { $acc . $x });

    is($concat, 'abcde', '... got the expected concatenation');
};

subtest '... reduce (find max)' => sub {
    my $max = Stream->of( 3, 7, 2, 9, 1, 5 )
        ->reduce(0, sub ($acc, $x) { $x > $acc ? $x : $acc });

    is($max, 9, '... got the expected max');
};

subtest '... reduce with BiFunction' => sub {
    my $sum = Stream->of( 1 .. 10 )
        ->reduce(0, BiFunction->new( f => sub ($acc, $x) { $acc + $x } ));

    is($sum, 55, '... got the expected sum with BiFunction');
};

done_testing;
