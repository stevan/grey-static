
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Debounce :isa(Stream::Operation::Node) {
    field $source :param;
    field $quiet_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $buffered_value = undef;
    field $has_buffered = false;
    field $last_update_time = undef;
    field $next;
    field $next_ready = false;

    method next {
        $next_ready = false;
        return $next;
    }

    method has_next {
        # If we already have a value ready, return true
        return true if $next_ready;

        # Pull source elements while available
        while ($source->has_next) {
            $buffered_value = $source->next;
            $has_buffered = true;
            $last_update_time = $executor->current_time;
        }

        # Check if quiet period has elapsed
        if ($has_buffered && defined $last_update_time) {
            my $current_time = $executor->current_time;
            my $elapsed = $current_time - $last_update_time;

            if ($elapsed >= $quiet_delay) {
                $next = $buffered_value;
                $next_ready = true;
                $has_buffered = false;
                $buffered_value = undef;
                return true;
            }
        }

        return false;
    }
}
