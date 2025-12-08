
use v5.42;
use experimental qw[ class ];

class BiConsumer {
    field $f :param :reader;

    method accept($t, $u) { $f->($t, $u); return }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t, $u) { $f->($t, $u); $g->accept($t, $u); return } )
    }
}
