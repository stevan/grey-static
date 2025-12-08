use v5.42;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

use Path::Tiny qw[ path ];

# Create a test file with known content
my $temp_file = Path::Tiny->tempfile;
my $content = "Hello World!\n";
$temp_file->spew($content);

subtest '... bytes with default size (1 byte)' => sub {
    my @bytes = IO::Stream::Files
        ->bytes($temp_file->stringify)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@bytes), length($content), '... got correct number of bytes');
    is(join('', @bytes), $content, '... bytes concatenate to original content');
};

subtest '... bytes with size 1' => sub {
    my @bytes = IO::Stream::Files
        ->bytes($temp_file->stringify, size => 1)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@bytes), length($content), '... got correct number of single bytes');
    ok((grep { length($_) == 1 } @bytes) == scalar(@bytes), '... all chunks are 1 byte');
};

subtest '... bytes with size 4' => sub {
    my @bytes = IO::Stream::Files
        ->bytes($temp_file->stringify, size => 4)
        ->collect( Stream::Collectors->ToList );

    # "Hello World!\n" = 13 bytes, should be 4 chunks: 4+4+4+1
    is(scalar(@bytes), 4, '... got correct number of 4-byte chunks');
    is(length($bytes[0]), 4, '... first chunk is 4 bytes');
    is(length($bytes[1]), 4, '... second chunk is 4 bytes');
    is(length($bytes[2]), 4, '... third chunk is 4 bytes');
    is(length($bytes[3]), 1, '... last chunk is 1 byte (remainder)');
    is(join('', @bytes), $content, '... chunks concatenate to original');
};

subtest '... bytes with large size' => sub {
    my @bytes = IO::Stream::Files
        ->bytes($temp_file->stringify, size => 1024)
        ->collect( Stream::Collectors->ToList );

    is(scalar(@bytes), 1, '... got single chunk');
    is($bytes[0], $content, '... chunk is entire content');
};

subtest '... bytes with exact file size' => sub {
    my @bytes = IO::Stream::Files
        ->bytes($temp_file->stringify, size => length($content))
        ->collect( Stream::Collectors->ToList );

    is(scalar(@bytes), 1, '... got single chunk');
    is($bytes[0], $content, '... chunk is entire content');
};

subtest '... bytes with file handle' => sub {
    open my $fh, '<', $temp_file->stringify or die "Cannot open: $!";

    my @bytes = IO::Stream::Files
        ->bytes($fh, size => 3)
        ->collect( Stream::Collectors->ToList );

    close $fh;

    ok(scalar(@bytes) > 0, '... read bytes from handle');
    is(join('', @bytes), $content, '... got correct content');
};

done_testing;
