
use v5.42;
use experimental qw[ class ];

class Flow::Operation::Grep :isa(Flow::Operation) {
    field $f :param;

    method apply ($e) {
        $self->submit( $e ) if $f->test( $e );
    }
}
