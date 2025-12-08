#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency::reactive ];

my @seen;

my $publisher  = Flow::Publisher->new;
my $subscriber = Flow::Subscriber->new(
    request_size => 1,
    consumer => Consumer->new( f => sub ($e) {
        push @seen => $e;
        $publisher->submit( $e + 1 ) unless $e >= 10;
    })
);
$publisher->subscribe($subscriber);

$publisher->submit( 1 );

$publisher->start;
$publisher->close;

eq_or_diff(\@seen, [1 .. 10], '... got the expected seen');

done_testing;




