
use v5.40;
use experimental qw[ class ];

use Function;

class BiFunction {
    field $f :param :reader;

    method apply ($t, $u) { return $f->($t, $u); }

    method curry    ($t) { Function ->new( f => sub ($u)     { return $f->($t, $u) } ) }
    method rcurry   ($u) { Function ->new( f => sub ($t)     { return $f->($t, $u) } ) }
    method and_then ($g) { __CLASS__->new( f => sub ($t, $u) { return $g->apply($f->($t, $u)) } ) }
}
