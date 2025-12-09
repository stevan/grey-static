
use v5.42;
use experimental qw[ class ];
use grey::static::error;

use Supplier;

class Function {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for Function",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method apply ($t) { return $f->($t); }

    method curry    ($t) { Supplier ->new( f => sub      { return $f->($t) } ) }
    method compose  ($g) { __CLASS__->new( f => sub ($t) { return $f->($g->apply($t)) } ) }
    method and_then ($g) { __CLASS__->new( f => sub ($t) { return $g->apply($f->($t)) } ) }
}
