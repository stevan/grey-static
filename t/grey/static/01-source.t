#!/usr/bin/env perl
use v5.42;
use Test::More;

use grey::static::source;

# Test caching the current file
my $source = grey::static::source->cache_file(__FILE__);
ok($source, 'cache_file returns a source object');
isa_ok($source, 'grey::static::source::File');

# Test get_source
my $source2 = grey::static::source->get_source(__FILE__);
ok($source2, 'get_source returns a source object');
is($source, $source2, 'get_source returns cached object');

# Test File methods
is($source->path, __FILE__, 'path returns correct file path');
ok($source->line_count > 0, 'line_count returns positive number');

# Test get_line
my $line1 = $source->get_line(1);
is($line1, '#!/usr/bin/env perl', 'get_line(1) returns shebang');

my $line2 = $source->get_line(2);
is($line2, 'use v5.42;', 'get_line(2) returns use statement');

# Test out of bounds
is($source->get_line(0), undef, 'get_line(0) returns undef');
is($source->get_line(99999), undef, 'get_line(99999) returns undef');

# Test get_lines
my @lines = $source->get_lines(1, 3);
is(scalar @lines, 3, 'get_lines returns correct number of lines');
is($lines[0], '#!/usr/bin/env perl', 'first line is correct');

# Test non-existent file
my $bad_source = grey::static::source->get_source('/nonexistent/file.pl');
is($bad_source, undef, 'get_source returns undef for non-existent file');

done_testing;
