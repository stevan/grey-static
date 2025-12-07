
use v5.40;
use experimental qw[ class ];

class IO::Stream::Source::FilesFromDirectory :isa(Stream::Source) {
    field $dir :param :reader;

    field $handle;
    field $next;

    ADJUST {
        opendir( $handle, $dir )
            || die "Unable to open $dir because $!";
    }

    method next { $next }

    method has_next {
        while (true) {
            if ( my $name = readdir( $handle ) ) {
                next unless defined $name;

                next if $name eq '.' || $name eq '..'; # skip these ...

                $next = $dir->child( $name );

                # directory is not readable or has been removed, so skip it
                if ( ! -r $next ) {
                    next;
                }
                else {
                    return true;
                }
            }
            else {
                last;
            }
        }

        return false;

    }
}
