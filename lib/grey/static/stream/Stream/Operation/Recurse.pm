
use v5.40;
use experimental qw[ class ];

class Stream::Operation::Recurse :isa(Stream::Operation::Node) {
    field $source      :param :reader;
    field $can_recurse :param :reader;
    field $recurse     :param :reader;

    field $next;
    field @stack;

    ADJUST {
        push @stack => $source;
    }

    method next { $next }

    method has_next {
        while (@stack) {
            if ($stack[-1]->has_next) {
                my $candidate = $stack[-1]->next;
                if ( $can_recurse->test( $candidate ) ) {
                    push @stack => $recurse->apply($candidate);
                }

                $next = $candidate;
                return true;
            }
            else {
                pop @stack;
                next;
            }
        }
        return false;
    }

}
