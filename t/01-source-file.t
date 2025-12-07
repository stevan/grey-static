#!/usr/bin/env perl
use v5.40;
use Test::More;
use File::Temp qw(tempfile);

use_ok('BetterErrors');

# Create a temporary file with known content
my ($fh, $filename) = tempfile(UNLINK => 1);
print $fh <<'SOURCE';
line 1
line 2
line 3
line 4
line 5
SOURCE
close $fh;

subtest 'SourceFile basic operations' => sub {
    my $source = BetterErrors::SourceFile->new(path => $filename);
    isa_ok($source, 'BetterErrors::SourceFile');

    is($source->path, $filename, 'path accessor works');
    is($source->line_count, 5, 'line_count is correct');
};

subtest 'get_line' => sub {
    my $source = BetterErrors::SourceFile->new(path => $filename);

    is($source->get_line(1), 'line 1', 'get_line(1) returns first line');
    is($source->get_line(3), 'line 3', 'get_line(3) returns third line');
    is($source->get_line(5), 'line 5', 'get_line(5) returns last line');

    is($source->get_line(0), undef, 'get_line(0) returns undef');
    is($source->get_line(6), undef, 'get_line(6) returns undef for out of bounds');
    is($source->get_line(-1), undef, 'get_line(-1) returns undef for negative');
};

subtest 'get_lines' => sub {
    my $source = BetterErrors::SourceFile->new(path => $filename);

    my @lines = $source->get_lines(2, 4);
    is_deeply(\@lines, ['line 2', 'line 3', 'line 4'], 'get_lines(2,4) returns correct range');

    @lines = $source->get_lines(1, 1);
    is_deeply(\@lines, ['line 1'], 'get_lines(1,1) returns single line');

    @lines = $source->get_lines(0, 2);
    is_deeply(\@lines, ['line 1', 'line 2'], 'get_lines clamps start to 1');

    @lines = $source->get_lines(4, 10);
    is_deeply(\@lines, ['line 4', 'line 5'], 'get_lines clamps end to line_count');
};

subtest 'non-existent file' => sub {
    my $source = BetterErrors::SourceFile->new(path => '/nonexistent/file.pl');
    is($source->line_count, 0, 'non-existent file has 0 lines');
    is($source->get_line(1), undef, 'get_line returns undef for non-existent file');
};

done_testing;
