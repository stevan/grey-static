use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::io;

our $VERSION = '0.01';

use File::Basename ();

sub import {
    my ($class, @subfeatures) = @_;

    # If no subfeatures specified, do nothing
    return unless @subfeatures;

    # Load each subfeature
    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'stream') {
            # Add the stream directory to @INC
            use lib File::Basename::dirname(__FILE__) . '/io/stream';

            # Load the IO::Stream classes
            load_module('IO::Stream::Files');
            load_module('IO::Stream::Directories');
        }
        else {
            die "Unknown io subfeature: $subfeature";
        }
    }
}

1;
