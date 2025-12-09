
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Consumer {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for Consumer",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method accept($t) { $f->($t); return }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t) { $f->($t); $g->accept($t); return } )
    }
}

