
use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional concurrency ];

my @grepped1;
my @grepped2;
my @mapped1;
my @mapped2;
my @seen;

my $publisher  = Flow
    ->from(Flow::Publisher->new)
    ->grep(sub ($e) {
        push @grepped1 => $e;
        ($e % 2) == 0
    })
    ->map(sub ($e) {
        push @mapped1 => $e;
        $e * 2
    })
    ->map(sub ($e) {
        push @mapped2 => $e;
        $e * 100
    })
    ->grep(sub ($e) {
        push @grepped2 => $e;
        $e > 1000
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

eq_or_diff(\@grepped1, [1 .. 10], '... got the expected grepped(1)');
eq_or_diff(\@mapped1,  [2,4,6,8,10], '... got the expected mapped(1)');
eq_or_diff(\@mapped2,  [4,8,12,16,20], '... got the expected mapped(2)');
eq_or_diff(\@grepped2, [400,800,1200,1600,2000], '... got the expected grepped(2)');
eq_or_diff(\@seen,     [1200,1600,2000], '... got the expected seen');

done_testing;




