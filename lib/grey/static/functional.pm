use v5.40;
use experimental qw[ class ];

package grey::static::functional;

our $VERSION = '0.01';

sub import { }

# -----------------------------------------------------------------------------
# Supplier - no-arg function that produces a value
# -----------------------------------------------------------------------------

class Supplier {
    field $f :param :reader;

    method get { $f->() }
}

# -----------------------------------------------------------------------------
# Function - single-arg function that transforms a value
# -----------------------------------------------------------------------------

class Function {
    field $f :param :reader;

    method apply ($t) { $f->($t) }

    method curry ($t) {
        Supplier->new( f => sub { $f->($t) } )
    }

    method compose ($g) {
        __CLASS__->new( f => sub ($t) { $f->($g->apply($t)) } )
    }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t) { $g->apply($f->($t)) } )
    }
}

# -----------------------------------------------------------------------------
# BiFunction - two-arg function that transforms values
# -----------------------------------------------------------------------------

class BiFunction {
    field $f :param :reader;

    method apply ($t, $u) { $f->($t, $u) }

    method curry ($t) {
        Function->new( f => sub ($u) { $f->($t, $u) } )
    }

    method rcurry ($u) {
        Function->new( f => sub ($t) { $f->($t, $u) } )
    }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t, $u) { $g->apply($f->($t, $u)) } )
    }
}

# -----------------------------------------------------------------------------
# Predicate - single-arg function that returns boolean
# -----------------------------------------------------------------------------

class Predicate {
    field $f :param :reader;

    method test ($t) { !!$f->($t) }

    method not {
        __CLASS__->new( f => sub ($t) { !$f->($t) } )
    }

    method and ($p) {
        __CLASS__->new( f => sub ($t) { $f->($t) && $p->test($t) } )
    }

    method or ($p) {
        __CLASS__->new( f => sub ($t) { $f->($t) || $p->test($t) } )
    }
}

# -----------------------------------------------------------------------------
# Consumer - single-arg function with no return value
# -----------------------------------------------------------------------------

class Consumer {
    field $f :param :reader;

    method accept ($t) { $f->($t); return }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t) { $f->($t); $g->accept($t); return } )
    }
}

# -----------------------------------------------------------------------------
# BiConsumer - two-arg function with no return value
# -----------------------------------------------------------------------------

class BiConsumer {
    field $f :param :reader;

    method accept ($t, $u) { $f->($t, $u); return }

    method and_then ($g) {
        __CLASS__->new( f => sub ($t, $u) { $f->($t, $u); $g->accept($t, $u); return } )
    }
}

# -----------------------------------------------------------------------------
# Comparator - comparison function for sorting
# -----------------------------------------------------------------------------

class Comparator {
    field $f :param :reader;

    method compare ($l, $r) { $f->($l, $r) }

    method reversed {
        __CLASS__->new( f => sub ($l, $r) {
            my $result = $f->($l, $r);
            return -$result;
        })
    }

    sub numeric ($class) {
        state $singleton = $class->new( f => sub ($l, $r) { $l <=> $r } );
    }

    sub alpha ($class) {
        state $singleton = $class->new( f => sub ($l, $r) { $l cmp $r } );
    }
}

1;
