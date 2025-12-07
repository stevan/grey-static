use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use grey::static qw[ functional stream io::stream ];

use Path::Tiny qw[ path ];

# Create a temporary directory structure for testing
my $temp_dir = Path::Tiny->tempdir;
my $subdir1 = $temp_dir->child('dir1');
my $subdir2 = $temp_dir->child('dir2');
$subdir1->mkpath;
$subdir2->mkpath;

# Create some test files
$temp_dir->child('file1.txt')->spew("file1\n");
$temp_dir->child('file2.txt')->spew("file2\n");
$subdir1->child('file3.txt')->spew("file3\n");
$subdir2->child('file4.txt')->spew("file4\n");

subtest '... testing Directories->files()' => sub {
    my @files = IO::Stream::Directories
        ->files($temp_dir)
        ->map(sub ($path) { $path->basename })
        ->collect( Stream::Collectors->ToList );

    my @sorted = sort @files;
    eq_or_diff(
        \@sorted,
        [sort qw(dir1 dir2 file1.txt file2.txt)],
        '... got all files and directories in top level'
    );
};

subtest '... testing Directories->files() with filter' => sub {
    my @files = IO::Stream::Directories
        ->files($temp_dir)
        ->grep(sub ($path) { $path->is_file })
        ->map(sub ($path) { $path->basename })
        ->collect( Stream::Collectors->ToList );

    my @sorted = sort @files;
    eq_or_diff(
        \@sorted,
        [qw(file1.txt file2.txt)],
        '... got only files'
    );
};

subtest '... testing Directories->files() with subdirectory' => sub {
    my @files = IO::Stream::Directories
        ->files($subdir1)
        ->map(sub ($path) { $path->basename })
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(
        \@files,
        ['file3.txt'],
        '... got file in subdirectory'
    );
};

subtest '... testing Directories->files() filters out . and ..' => sub {
    my @files = IO::Stream::Directories
        ->files($temp_dir)
        ->map(sub ($path) { $path->basename })
        ->collect( Stream::Collectors->ToList );

    ok(!(grep { $_ eq '.' || $_ eq '..' } @files), '... no . or .. in results');
};

subtest '... testing Directories->files() with empty directory' => sub {
    my $empty_dir = $temp_dir->child('empty');
    $empty_dir->mkpath;

    my @files = IO::Stream::Directories
        ->files($empty_dir)
        ->collect( Stream::Collectors->ToList );

    eq_or_diff(\@files, [], '... empty directory produces empty stream');
};

done_testing;
