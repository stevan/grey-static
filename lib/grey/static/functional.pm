use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::functional;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/functional';

load_module('Supplier');
load_module('Function');
load_module('BiFunction');
load_module('Predicate');
load_module('Consumer');
load_module('BiConsumer');
load_module('Comparator');

sub import { }

1;
