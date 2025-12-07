
use v5.40;
use experimental qw[ class ];

class Supplier {
    field $f :param :reader;

    method get { return $f->(); }
}
