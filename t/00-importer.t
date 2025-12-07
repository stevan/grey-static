#!/usr/bin/env perl
use v5.40;
no warnings 'shadow';  # Suppress builtin shadow warnings
use Test::More;

use_ok('importer');

# Test importing from List::Util
use importer 'List::Util' => qw[ sum ];
is(sum(1, 2, 3), 6, 'sum imported and works');

# Test importing from Scalar::Util
use importer 'Scalar::Util' => qw[ looks_like_number ];
ok(looks_like_number(42), 'looks_like_number imported and works');

done_testing;
