use v5.40;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static;

our $VERSION = '0.01';

sub import {
    my ($class, @features) = @_;
    my ($caller_package, $caller_file) = caller;

    # Always load and initialize source caching
    load_module('grey::static::source');
    grey::static::source->cache_file($caller_file);

    # Load each requested feature
    for my $feature (@features) {
        my $module = "grey::static::${feature}";
        load_module($module);
        $module->import();
    }
}

1;
