use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static;

our $VERSION = '0.01';

# Load core utilities
load_module('importer');

sub import {
    my ($class, @features) = @_;
    my ($caller_package, $caller_file) = caller;

    # Always load and initialize source caching
    load_module('grey::static::source');
    grey::static::source->cache_file($caller_file);

    # Load each requested feature
    for my $feature (@features) {
        # Check if this is a sub-feature (contains ::)
        if ($feature =~ /^([^:]+)::(.+)$/) {
            my $base_feature = $1;
            my $subfeature = $2;

            # Load the base feature module
            my $module = "grey::static::${base_feature}";
            load_module($module);

            # Call its import with the subfeature
            $module->import($subfeature);
        }
        else {
            # Simple feature without sub-features
            my $module = "grey::static::${feature}";
            load_module($module);
            $module->import();
        }
    }
}

1;
