
use v5.40;
use experimental qw[ class ];

class Stream::Operation::TakeUntil :isa(Stream::Operation::Node) {
    field $source    :param;
    field $predicate :param;

    field $done = false;
    field $next = undef;

    method next { $next }

    method has_next {
        return false if $done || !$source->has_next;
        $next = $source->next;
        $done = $predicate->test($next);
        return true;
    }
}
