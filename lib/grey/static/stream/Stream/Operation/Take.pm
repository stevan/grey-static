
use v5.40;
use experimental qw[ class ];

class Stream::Operation::Take :isa(Stream::Operation::Node) {
    field $source :param;
    field $amount :param;

    field $taken = 0;
    field $next = undef;

    method next { $next }

    method has_next {
        return false if $taken >= $amount;
        $next = $source->next;
        $taken++;
        return true;
    }
}
