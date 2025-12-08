use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::datatypes;

our $VERSION = '0.01';

use File::Basename ();

sub import {
    my ($class, @subfeatures) = @_;

    # If no subfeatures specified, do nothing
    return unless @subfeatures;

    # Load each subfeature
    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'ml') {
            # Add the ml directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/datatypes/ml';

            # Load the ML datatype classes
            load_module('Tensor');
            load_module('Scalar');
            load_module('Vector');
            load_module('Matrix');
        }
        else {
            die "Unknown datatypes subfeature: $subfeature";
        }
    }
}

1;
