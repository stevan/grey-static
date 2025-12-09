
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Predicate {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for Predicate",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method test ($t) { return (!!$f->($t)); }

    method not      { __CLASS__->new( f => sub ($t) { return !(!!$f->($t)) } ) }
    method and ($p) { __CLASS__->new( f => sub ($t) { return (!!$f->($t)) && (!!$p->test($t)) } ) }
    method or  ($p) { __CLASS__->new( f => sub ($t) { return (!!$f->($t)) || (!!$p->test($t)) } ) }
}
