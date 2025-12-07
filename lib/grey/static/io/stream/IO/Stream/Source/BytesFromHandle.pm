
use v5.40;
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
}
