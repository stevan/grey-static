
use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency::util ];

my $exe2 = Executor->new;
my $exe1 = Executor->new( next => $exe2 );

my @got;

sub ping ($n) {
    sub {
        push @got => "ping($n)";
        $exe2->next_tick(pong($n - 1)) if $n;
    }
}

sub pong ($n) {
    sub {
        push @got => "pong($n)";
        $exe1->next_tick(ping($n - 1)) if $n;
    }
}

$exe1->next_tick(ping(10));
$exe1->run;

eq_or_diff(
    \@got,
    [qw[
        ping(10)
        pong(9)
        ping(8)
        pong(7)
        ping(6)
        pong(5)
        ping(4)
        pong(3)
        ping(2)
        pong(1)
        ping(0)
    ]],
    '... got the expected data'
);

done_testing;
