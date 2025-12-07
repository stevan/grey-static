
use v5.40;
use experimental qw[ class ];

class Stream::Operation::Every :isa(Stream::Operation::Node) {
    field $source :param :reader;
    field $stride :param :reader;
    field $event  :param :reader;

    field $seen = -1;

    method next {
        my $next = $source->next;
        if (++$seen >= $stride) {
            $event->accept($next);
            $seen = 0;
        }
        return $next;
    }

    method has_next { $source->has_next }
}
