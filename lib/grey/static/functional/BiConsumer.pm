
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class BiConsumer {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for BiConsumer",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method accept($t, $u) { $f->($t, $u); return }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t, $u) { $f->($t, $u); $g->accept($t, $u); return } )
    }
}
