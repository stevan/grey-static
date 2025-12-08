
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Map :isa(Stream::Operation::Node) {
    field $source :param;
    field $mapper :param;

    method next     { $mapper->apply( $source->next ) }
    method has_next { $source->has_next }
}
