use v5.40;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::io::stream;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/stream';

load_module('IO::Stream::Files');
load_module('IO::Stream::Directories');

sub import { }

1;
