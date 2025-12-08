#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream ];

my @opened;
my @closed;

sub open  ($s) { push @opened => blessed $s->source }
sub close ($s) { push @closed => blessed $s->source }

my @result = Stream->of( 0 .. 10 ) ->on_open(\&open)->on_close(\&close)
->grep(sub ($i) { ($i % 2) == 0 }) ->on_open(\&open)->on_close(\&close)
->map(sub ($i) { $i * 2 })         ->on_open(\&open)->on_close(\&close)
->peek(sub {})                     ->on_open(\&open)->on_close(\&close)
->collect( Stream::Collectors->ToList );

eq_or_diff(
    [@opened],
    [qw[
        Stream::Source::FromArray
        Stream::Operation::Grep
        Stream::Operation::Map
        Stream::Operation::Peek
    ]],
    '... got the expected opens'
);

eq_or_diff(
    [@closed],
    [qw[
        Stream::Operation::Peek
        Stream::Operation::Map
        Stream::Operation::Grep
        Stream::Source::FromArray
    ]],
    '... got the expected closes'
);

eq_or_diff(
    [@result],
    [ 0, 4, 8, 12, 16, 20 ],
    '... got the expected results'
);



done_testing;
