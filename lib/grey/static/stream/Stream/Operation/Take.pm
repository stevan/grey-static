
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Take :isa(Stream::Operation::Node) {
    field $source :param;
    field $amount :param;

    field $taken = 0;
    field $next = undef;

    method next { $next }

    method has_next {
        return false if $taken >= $amount;
        return false unless $source->has_next;
        $next = $source->next;
        $taken++;
        return true;
    }
}
