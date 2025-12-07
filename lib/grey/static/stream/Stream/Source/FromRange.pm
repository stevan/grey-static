
use v5.40;
use experimental qw[ class ];

class Stream::Source::FromRange :isa(Stream::Source) {
    field $start :param :reader;
    field $end   :param :reader;
    field $step  :param :reader = 1;

    field $current;
    ADJUST {
        $current = $start;
    }

    method next {
        my $next = $current;
        $current += $step;
        return $next;
    }

    method has_next { $current <= $end }
}
