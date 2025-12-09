
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Comparator {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for Comparator",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method compare ($l, $r) { return $f->($l, $r) }

    method reversed {
        __CLASS__->new( f => sub ($l, $r) {
            my $result = $f->($l, $r);
            return -1 if $result > 0;
            return  1 if $result < 0;
            return 0;
        })
    }

    sub numeric ($class) {
        state $singleton = $class->new( f => sub ($l, $r) { $l <=> $r } );
    }

    sub alpha ($class) {
        state $singleton = $class->new( f => sub ($l, $r) { $l cmp $r } );
    }
}
