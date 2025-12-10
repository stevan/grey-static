
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Stream::Operation::Timeout :isa(Stream::Operation::Node) {
    field $source :param;
    field $timeout_delay :param;
    field $executor :param;  # ScheduledExecutor

    field $last_element_time = 0;
    field $next;

    method next { $next }

    method has_next {
        my $current_time = $executor->current_time;
        my $elapsed = $current_time - $last_element_time;

        if ($elapsed >= $timeout_delay) {
            Error->throw(
                message => "Stream timeout",
                hint => "No element received within $timeout_delay ticks"
            );
        }

        if ($source->has_next) {
            $next = $source->next;
            $last_element_time = $executor->current_time;
            return true;
        }

        return false;
    }
}
