#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency ];

my @seen;

my $publisher  = Flow::Publisher->new;
my $subscriber = Flow::Subscriber->new(
    request_size => 2,
    consumer => Consumer->new( f => sub ($e) {
        push @seen => $e;
    })
);

$publisher->subscribe($subscriber);

foreach ( 1 .. 10 ) {
    $publisher->submit( $_ );
}

$publisher->start;
$publisher->close;

eq_or_diff(\@seen, [1 .. 10], '... got the expected seen');

done_testing;




