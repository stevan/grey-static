use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

use Path::Tiny qw[ path ];

# Create test files with different line endings
my $temp_file = Path::Tiny->tempfile;
my @lines = ("Line 1\n", "Line 2\n", "Line 3\n", "Line 4");
$temp_file->spew(@lines);

subtest '... lines from file path' => sub {
    my @result = IO::Stream::Files
        ->lines($temp_file->stringify)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@result), 4, '... got 4 lines');
    eq_or_diff(\@result, \@lines, '... lines match original');
};

subtest '... lines with map to remove newlines' => sub {
    my @result = IO::Stream::Files
        ->lines($temp_file->stringify)
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, ['Line 1', 'Line 2', 'Line 3', 'Line 4'], '... chomped lines');
};

subtest '... lines with filter' => sub {
    my @result = IO::Stream::Files
        ->lines($temp_file->stringify)
        ->grep(sub ($line) { $line =~ /2|3/ })
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@result, ['Line 2', 'Line 3'], '... filtered lines');
};

subtest '... lines with file handle' => sub {
    open my $fh, '<', $temp_file->stringify or die "Cannot open: $!";

    my @result = IO::Stream::Files
        ->lines($fh)
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->ToList );

    close $fh;

    eq_or_diff(\@result, ['Line 1', 'Line 2', 'Line 3', 'Line 4'], '... got lines from handle');
};

subtest '... lines with IO::File object' => sub {
    use IO::File;
    my $fh = IO::File->new($temp_file->stringify, '<') or die "Cannot open: $!";

    my @result = IO::Stream::Files
        ->lines($fh)
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->ToList );

    $fh->close;

    eq_or_diff(\@result, ['Line 1', 'Line 2', 'Line 3', 'Line 4'], '... got lines from IO::File');
};

done_testing;
