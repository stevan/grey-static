use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

use Path::Tiny qw[ path ];

subtest '... empty file with lines' => sub {
    my $empty_file = Path::Tiny->tempfile;
    $empty_file->spew('');

    my @lines = IO::Stream::Files
        ->lines($empty_file->stringify)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@lines, [], '... empty file produces no lines');
};

subtest '... empty file with bytes' => sub {
    my $empty_file = Path::Tiny->tempfile;
    $empty_file->spew('');

    my @bytes = IO::Stream::Files
        ->bytes($empty_file->stringify, size => 8)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@bytes, [], '... empty file produces no bytes');
};

subtest '... single line file without newline' => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew('single line');

    my @lines = IO::Stream::Files
        ->lines($file->stringify)
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@lines, ['single line'], '... got single line without newline');
};

subtest '... file with only newlines' => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew("\n\n\n");

    my @lines = IO::Stream::Files
        ->lines($file->stringify)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@lines), 3, '... got 3 empty lines');
    eq_or_diff(\@lines, ["\n", "\n", "\n"], '... each line is a newline');
};

subtest '... file with mixed line endings' => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew("Line 1\nLine 2\nLine 3");

    my @lines = IO::Stream::Files
        ->lines($file->stringify)
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@lines, ['Line 1', 'Line 2', 'Line 3'], '... handled mixed endings');
};

subtest '... bytes from binary data' => sub {
    my $file = Path::Tiny->tempfile;
    # Write some binary data (null bytes, high bytes, etc.)
    $file->spew_raw("\x00\xFF\x01\x7F\x80");

    my @bytes = IO::Stream::Files
        ->bytes($file->stringify, size => 1)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@bytes), 5, '... got 5 bytes');
    is(ord($bytes[0]), 0x00, '... first byte is null');
    is(ord($bytes[1]), 0xFF, '... second byte is 0xFF');
    is(ord($bytes[2]), 0x01, '... third byte is 0x01');
};

subtest '... lines with very long line' => sub {
    my $file = Path::Tiny->tempfile;
    my $long_line = 'x' x 10000 . "\n";
    $file->spew($long_line);

    my @lines = IO::Stream::Files
        ->lines($file->stringify)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@lines), 1, '... got 1 line');
    is(length($lines[0]), 10001, '... line has correct length');
};

subtest '... bytes with size larger than file' => sub {
    my $file = Path::Tiny->tempfile;
    $file->spew("small");

    my @bytes = IO::Stream::Files
        ->bytes($file->stringify, size => 1000)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@bytes), 1, '... got single chunk');
    is($bytes[0], 'small', '... chunk contains entire file');
};

done_testing;
