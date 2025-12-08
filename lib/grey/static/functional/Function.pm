
use v5.42;
use experimental qw[ class ];

use Supplier;

class Function {
    field $f :param :reader;

    method apply ($t) { return $f->($t); }

    method curry    ($t) { Supplier ->new( f => sub      { return $f->($t) } ) }
    method compose  ($g) { __CLASS__->new( f => sub ($t) { return $f->($g->apply($t)) } ) }
    method and_then ($g) { __CLASS__->new( f => sub ($t) { return $g->apply($f->($t)) } ) }
}
