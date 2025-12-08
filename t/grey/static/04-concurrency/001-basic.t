
use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency::reactive ];

my @grepped;
my @mapped;
my @seen;

my $publisher  = Flow
    ->from(Flow::Publisher->new)
    ->grep(sub ($e) {
        push @grepped => $e;
        ($e % 2) == 0
    })
    ->map(sub ($e) {
        push @mapped => $e;
        $e * 2
    })
    ->to(sub ($e) {
        push @seen => $e;
    })
    ->build
;

foreach ( 1 .. 10 ) {
    $publisher->submit( $_ );
}

$publisher->start;
$publisher->close;

eq_or_diff(\@grepped, [1 .. 10], '... got the expected grepped');
eq_or_diff(\@mapped,  [2,4,6,8,10], '... got the expected mapped');
eq_or_diff(\@seen,    [4,8,12,16,20], '... got the expected seen');

done_testing;




