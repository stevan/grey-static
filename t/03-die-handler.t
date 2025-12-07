#!/usr/bin/env perl
use v5.40;
use Test::More;

use_ok('BetterErrors');

# Disable colors for predictable output
BetterErrors::set_colors(0);

subtest 'die handler is installed on import' => sub {
    ok(defined $SIG{__DIE__}, 'die handler is installed');
};

subtest 'die in eval does not trigger handler' => sub {
    my $result = eval {
        die "test error in eval";
        1;
    };

    is($result, undef, 'eval caught the die');
    like($@, qr/test error in eval/, 'original error preserved in eval');
    # The error should NOT be formatted since we're in eval
    unlike($@, qr/error occurred here/, 'formatted error not used in eval');
};

subtest 'error parsing' => sub {
    # Test the internal _parse_error function
    no warnings 'once';

    my ($msg, $file, $line) = BetterErrors::_parse_error(
        "Can't call method on undefined value at script.pl line 42."
    );
    is($msg, "Can't call method on undefined value", 'parses message');
    is($file, 'script.pl', 'parses file');
    is($line, 42, 'parses line');

    ($msg, $file, $line) = BetterErrors::_parse_error(
        "Undefined subroutine &main::foo at /path/to/file.pm line 123, near \"}\""
    );
    is($msg, 'Undefined subroutine &main::foo', 'parses complex message');
    is($file, '/path/to/file.pm', 'parses absolute path');
    is($line, 123, 'parses line from complex error');

    ($msg, $file, $line) = BetterErrors::_parse_error("Simple error");
    is($msg, 'Simple error', 'handles error without location');
    is($file, undef, 'file is undef for simple error');
    is($line, undef, 'line is undef for simple error');
};

subtest 'unimport restores handler' => sub {
    my $original = $SIG{__DIE__};

    {
        package TestPackage;
        use BetterErrors;
        no BetterErrors;
    }

    # After unimport in TestPackage, our main handler should still be active
    ok(defined $SIG{__DIE__}, 'handler still active in main');
};

done_testing;
