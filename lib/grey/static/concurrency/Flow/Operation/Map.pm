
use v5.40;
use experimental qw[ class ];

class Flow::Operation::Map :isa(Flow::Operation) {
    field $f :param;

    method apply ($e) {
        $self->submit( $f->apply( $e ) );
    }
}
