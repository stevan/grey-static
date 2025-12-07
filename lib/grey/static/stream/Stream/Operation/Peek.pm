
use v5.40;
use experimental qw[ class ];

class Stream::Operation::Peek :isa(Stream::Operation::Node) {
    field $source   :param;
    field $consumer :param;

    method next {
        my $val = $source->next;
        $consumer->accept( $val );
        return $val;
    }

    method has_next { $source->has_next }
}
