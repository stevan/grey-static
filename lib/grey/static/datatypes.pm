use v5.40;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::datatypes;

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/datatypes';

load_module('Tensor');
load_module('Scalar');
load_module('Vector');
load_module('Matrix');

sub import { }

1;
