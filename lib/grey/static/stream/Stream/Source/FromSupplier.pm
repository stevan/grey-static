
use v5.42;
use experimental qw[ class ];

class Stream::Source::FromSupplier :isa(Stream::Source) {
    field $supplier :param :reader;

    method next { $supplier->get }
    method has_next { true }
}
