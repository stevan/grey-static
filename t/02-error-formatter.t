#!/usr/bin/env perl
use v5.40;
use Test::More;
use File::Temp qw(tempfile);

use_ok('BetterErrors');

# Disable colors for predictable test output
BetterErrors::set_colors(0);

# Create a temporary file with known content
my ($fh, $filename) = tempfile(UNLINK => 1, SUFFIX => '.pl');
print $fh <<'SOURCE';
#!/usr/bin/env perl
use v5.40;

sub foo {
    my $x = undef;
    $x->method();
}

foo();
SOURCE
close $fh;

subtest 'ErrorFormatter basic formatting' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 2);
    isa_ok($formatter, 'BetterErrors::ErrorFormatter');

    my $output = $formatter->format_error("Test error message", $filename, 6);

    like($output, qr/error: Test error message/, 'contains error message');
    like($output, qr/-->.*:\d+/, 'contains file:line reference');
    like($output, qr/\$x->method/, 'contains the error line source');
    like($output, qr/\^+/, 'contains pointer characters');
    like($output, qr/error occurred here/, 'contains error location text');
};

subtest 'context lines' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 1);
    my $output = $formatter->format_error("Error", $filename, 6);

    like($output, qr/my \$x = undef/, 'contains line before (context_lines=1)');
    like($output, qr/\$x->method/, 'contains error line');
    unlike($output, qr/sub foo/, 'does not contain line 2 lines before');
};

subtest 'format_error function' => sub {
    my $output = BetterErrors::format_error("Function test", $filename, 5);

    like($output, qr/error: Function test/, 'format_error function works');
    like($output, qr/my \$x = undef/, 'contains correct source line');
};

subtest 'handles missing file gracefully' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new();
    my $output = $formatter->format_error("No file", "/nonexistent/file.pl", 10);

    like($output, qr/error: No file/, 'contains error message');
    like($output, qr/-->.*nonexistent/, 'contains file reference');
    # Should not die, just skip source context
};

subtest 'handles edge cases' => sub {
    my $formatter = BetterErrors::ErrorFormatter->new(context_lines => 2);

    # Error at first line
    my $output = $formatter->format_error("First line", $filename, 1);
    like($output, qr/error: First line/, 'handles first line');

    # Error at last line
    $output = $formatter->format_error("Last line", $filename, 9);
    like($output, qr/error: Last line/, 'handles last line');

    # Invalid line number
    $output = $formatter->format_error("Invalid", $filename, 0);
    like($output, qr/error: Invalid/, 'handles line 0');
};

done_testing;
