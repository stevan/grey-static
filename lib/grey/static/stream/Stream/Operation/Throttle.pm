
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Throttle :isa(Stream::Operation::Node) {
    field $source :param;
    field $min_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $last_emit_time = undef;
    field $next;

    method next { $next }

    method has_next {
        return false unless $source->has_next;

        # First element or enough time has passed
        if (!defined $last_emit_time) {
            $next = $source->next;
            $last_emit_time = $executor->current_time;
            return true;
        }

        my $current_time = $executor->current_time;
        if (($current_time - $last_emit_time) >= $min_delay) {
            $next = $source->next;
            $last_emit_time = $executor->current_time;
            return true;
        }

        return false;
    }
}
