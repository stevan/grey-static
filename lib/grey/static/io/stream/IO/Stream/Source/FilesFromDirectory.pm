
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class IO::Stream::Source::FilesFromDirectory :isa(Stream::Source) {
    field $dir :param :reader;

    field $handle;
    field $next;

    ADJUST {
        Error->throw(
            message => "Unable to open directory: $dir",
            hint => "Error: $!"
        ) unless opendir( $handle, $dir );
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

    # Note: Directory handles are automatically closed when they go out of scope
}
