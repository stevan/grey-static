
use v5.42;
use experimental qw[ class ];
use grey::static::error;

use Function;

class BiFunction {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for BiFunction",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method apply ($t, $u) { return $f->($t, $u); }

    method curry    ($t) { Function ->new( f => sub ($u)     { return $f->($t, $u) } ) }
    method rcurry   ($u) { Function ->new( f => sub ($t)     { return $f->($t, $u) } ) }
    method and_then ($g) { __CLASS__->new( f => sub ($t, $u) { return $g->apply($f->($t, $u)) } ) }
}
