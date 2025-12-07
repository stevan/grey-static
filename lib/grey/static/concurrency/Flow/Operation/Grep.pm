
use v5.40;
use experimental qw[ class ];

class Flow::Operation::Grep :isa(Flow::Operation) {
    field $f :param;

    method apply ($e) {
        $self->submit( $e ) if $f->test( $e );
    }
}
