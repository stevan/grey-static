
use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

my @self = do {
    my $fh = IO::File->new(__FILE__, '<');
    map { chomp; $_ } <$fh>;
};

subtest '... testing IO->lines($fh)' => sub {
    open my $fh, '<', __FILE__;

    my @results = IO::Stream::Files
        ->lines($fh)
        ->map(sub ($line) { chomp $line; $line })
        ->collect( Stream::Collectors->ToList )
    ;

    eq_or_diff(\@results, \@self, '... got the expected results');
};

subtest '... testing IO->lines(IO::File)' => sub {

    my @results = IO::Stream::Files
        ->lines(IO::File->new(__FILE__, '<'))
        ->map(sub ($line) { chomp $line; $line })
        ->collect( Stream::Collectors->ToList )
    ;

    eq_or_diff(\@results, \@self, '... got the expected results');
};

subtest '... testing IO->lines(IO::File)' => sub {

    my @results = IO::Stream::Files
        ->lines(__FILE__)
        ->map(sub ($line) { chomp $line; $line })
        ->collect( Stream::Collectors->ToList )
    ;

    eq_or_diff(\@results, \@self, '... got the expected results');
};

done_testing;
