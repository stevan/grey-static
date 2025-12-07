
use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

open my $fh, '<', __FILE__;

my $s = IO::Stream::Files->bytes( $fh, size => 8 )->foreach(sub ($x) {
    ok(length($x) <= 8, '... nothing is longer than 8 characters')
});

done_testing;
