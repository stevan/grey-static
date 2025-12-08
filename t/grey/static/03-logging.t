#!/usr/bin/env perl
use v5.42;
use Test::More;

use grey::static qw[logging];

# Check that DEBUG is exported
ok(defined &DEBUG, 'DEBUG is exported');

# DEBUG should be false by default (no $ENV{DEBUG})
is(DEBUG, 0, 'DEBUG is false when $ENV{DEBUG} not set');

# Check that logging functions are exported
ok(defined &LOG, 'LOG is exported');
ok(defined &INFO, 'INFO is exported');
ok(defined &DIV, 'DIV is exported');
ok(defined &TICK, 'TICK is exported');
ok(defined &OPEN, 'OPEN is exported');
ok(defined &CLOSE, 'CLOSE is exported');

# Test that LOG can be called (capture output)
my $output = '';
{
    local *STDOUT;
    open STDOUT, '>', \$output;
    LOG 'TestClass', 'test message';
}
like($output, qr/TestClass/, 'LOG produces output with class name');
like($output, qr/test message/, 'LOG produces output with message');

done_testing;
