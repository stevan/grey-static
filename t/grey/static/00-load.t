#!/usr/bin/env perl
use v5.42;
use Test::More;

use_ok('grey::static');
use_ok('grey::static::source');
use_ok('grey::static::error');

ok($grey::static::VERSION, 'grey::static VERSION is set');
ok($grey::static::source::VERSION, 'grey::static::source VERSION is set');
ok($grey::static::error::VERSION, 'grey::static::error VERSION is set');

done_testing;
