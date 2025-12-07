use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

use Path::Tiny qw[ path ];

# Create test files for integration tests
my $temp_dir = Path::Tiny->tempdir;

# Create multiple text files with numbers
for my $i (1..5) {
    $temp_dir->child("file$i.txt")->spew("Number: $i\n");
}

# Create a data file with CSV-like content
my $csv_file = $temp_dir->child('data.csv');
$csv_file->spew("name,age\nAlice,30\nBob,25\nCharlie,35\n");

subtest '... read all files in directory and process' => sub {
    my @numbers = IO::Stream::Directories
        ->files($temp_dir)
        ->grep(sub ($path) { $path->basename =~ /^file\d+\.txt$/ })
        ->flat_map(sub ($path) { IO::Stream::Files->lines($path->stringify) })
        ->map(sub ($line) { chomp($line); $line })
        ->map(sub ($line) { $line =~ /(\d+)/; $1 })
        ->collect( Stream::Collectors->ToList );

    my @sorted = sort { $a <=> $b } @numbers;
    eq_or_diff(\@sorted, [1, 2, 3, 4, 5], '... extracted numbers from all files');
};

subtest '... process CSV file' => sub {
    my @data = IO::Stream::Files
        ->lines($csv_file->stringify)
        ->map(sub ($line) { chomp($line); $line })
        ->grep(sub ($line) { $line !~ /^name,/ })  # skip header
        ->map(sub ($line) { [split /,/, $line] })
        ->collect( Stream::Collectors->ToList );

    is(scalar(@data), 3, '... got 3 data rows');
    eq_or_diff($data[0], ['Alice', '30'], '... parsed first row');
    eq_or_diff($data[1], ['Bob', '25'], '... parsed second row');
    eq_or_diff($data[2], ['Charlie', '35'], '... parsed third row');
};

subtest '... count lines across multiple files' => sub {
    my $count = IO::Stream::Directories
        ->files($temp_dir)
        ->grep(sub ($path) { $path->is_file })
        ->flat_map(sub ($path) { IO::Stream::Files->lines($path->stringify) })
        ->reduce(0, sub ($val, $acc) { $acc + 1 });

    # 5 files with 1 line each + 1 CSV with 4 lines = 9 total
    is($count, 9, '... counted lines across all files');
};

subtest '... filter files by extension' => sub {
    my @txt_files = IO::Stream::Directories
        ->files($temp_dir)
        ->grep(sub ($path) { $path =~ /\.txt$/ })
        ->map(sub ($path) { $path->basename })
        ->collect( Stream::Collectors->ToList );

    my @sorted = sort @txt_files;
    ok(scalar(@sorted) == 5, '... found 5 txt files');
    ok((grep { /^file\d+\.txt$/ } @sorted) == 5, '... all are numbered files');
};

subtest '... join file contents' => sub {
    my $joined = IO::Stream::Directories
        ->files($temp_dir)
        ->grep(sub ($path) { $path->basename =~ /^file[12]\.txt$/ })
        ->flat_map(sub ($path) { IO::Stream::Files->lines($path->stringify) })
        ->map(sub ($line) { chomp($line); $line })
        ->collect( Stream::Collectors->JoinWith(' | ') );

    # Order may vary, so just check both files are present
    ok($joined =~ /Number: 1/, '... includes content from file1');
    ok($joined =~ /Number: 2/, '... includes content from file2');
};

subtest '... bytes and lines combination' => sub {
    # Read file as bytes, count them, then compare to line length
    my $test_file = $temp_dir->child('test.txt');
    $test_file->spew("Hello\nWorld\n");

    my $byte_count = IO::Stream::Files
        ->bytes($test_file->stringify, size => 1)
        ->reduce(0, sub ($val, $acc) { $acc + 1 });

    my $line_length = IO::Stream::Files
        ->lines($test_file->stringify)
        ->reduce(0, sub ($val, $acc) { $acc + length($val) });

    is($byte_count, $line_length, '... byte count equals total line length');
};

done_testing;
