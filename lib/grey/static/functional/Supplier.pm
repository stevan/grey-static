
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Supplier {
    field $f :param :reader;

    ADJUST {
        Error->throw(
            message => "Invalid 'f' parameter for Supplier",
            hint => "Expected a CODE reference, got: " . (ref($f) || 'scalar')
        ) unless ref($f) eq 'CODE';
    }

    method get { return $f->(); }
}
