use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::stream;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/stream';

load_module('Stream');

sub import { }

1;
