
use v5.42;
use experimental qw[ class ];

class Stream::Source::FromIterator :isa(Stream::Source) {
    field $seed     :param;
    field $next     :param;
    field $has_next :param;

    field $current;
    ADJUST {
        $current = $seed;
    }

    method     next { $current = $next->apply($current) }
    method has_next {
        return true unless defined $has_next;
        return $has_next->test($current);
    }
}
