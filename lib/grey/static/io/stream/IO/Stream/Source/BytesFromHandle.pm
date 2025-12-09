
use v5.42;
use experimental qw[ class ];

class IO::Stream::Source::BytesFromHandle :isa(Stream::Source) {
    field $fh   :param :reader;
    field $size :param :reader = 1;

    field $next;

    method next { $next }

    method has_next {
        my $result = sysread( $fh, $next, $size );
        return false if $result == 0;
        return true;
    }

    # Note: File handles are automatically closed when they go out of scope
}
