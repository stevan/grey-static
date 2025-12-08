
use v5.42;
use experimental qw[ class ];

class Stream::Operation::When :isa(Stream::Operation::Node) {
    field $source    :param;
    field $consumer  :param;
    field $predicate :param;

    method next {
        my $val = $source->next;
        $consumer->accept( $val ) if $predicate->test( $val );
        return $val;
    }

    method has_next { $source->has_next }
}
