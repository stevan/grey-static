#!/usr/bin/env perl
use v5.40;
use Test::More;

use_ok('BetterErrors');

# Check that the module exports the expected functions
can_ok('BetterErrors', qw(format_error set_colors import unimport));

# Check version
ok($BetterErrors::VERSION, 'VERSION is set');

done_testing;
