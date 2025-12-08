use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::concurrency;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/concurrency';

load_module('Flow');

sub import { }

1;
