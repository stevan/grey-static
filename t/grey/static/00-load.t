#!/usr/bin/env perl
use v5.42;
use Test::More;

use_ok('grey::static');
use_ok('grey::static::source');
use_ok('grey::static::diagnostics');

ok($grey::static::VERSION, 'grey::static VERSION is set');
ok($grey::static::source::VERSION, 'grey::static::source VERSION is set');
ok($grey::static::diagnostics::VERSION, 'grey::static::diagnostics VERSION is set');

done_testing;
