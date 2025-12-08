
use v5.42;
use experimental qw[ class ];

class Flow::Operation::Map :isa(Flow::Operation) {
    field $f :param;

    method apply ($e) {
        $self->submit( $f->apply( $e ) );
    }
}
