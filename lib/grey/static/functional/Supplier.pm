
use v5.42;
use experimental qw[ class ];

class Supplier {
    field $f :param :reader;

    method get { return $f->(); }
}
