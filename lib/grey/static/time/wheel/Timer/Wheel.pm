
use v5.42;
use experimental qw[ class ];
use grey::static::error;

use Timer::Wheel::State;

class Timer::Wheel {
    use constant DEBUG => $ENV{DEBUG} // 0;
    use constant DEPTH => 5;
    use constant MAX_TIMERS => 10000;

    field @wheel = map +[], 1 .. (DEPTH * 10);

    field $state = Timer::Wheel::State->new( num_gears => DEPTH - 1 );
    field $timer_count = 0;
    field %timers_by_id;

    method advance_by ($n) {
        while ($n) {
            $state->advance;

            my @changes = $state->changes;
            foreach my ($i, $change) (indexed @changes) {
                if ($change) {
                    my $index = $change + ($i * 10);
                    DEBUG && say "check index: ",$index;
                    $self->check_timers( $index, $i );
                }
            }

            $n--;
        }
    }

    method check_timers ($index, $depth) {
        my $bucket = $wheel[$index];
        if (@$bucket) {
            DEBUG && say "checking wheel[$index] found ".(scalar @$bucket)." timer(s)";
            while (@$bucket) {
                my $timer = shift @$bucket;
                $timer_count--;
                if ($timer->expiry == $state->time) {
                    DEBUG && say "Got a timer($timer) event to fire! ";
                    # Remove from tracking when fired
                    delete $timers_by_id{$timer->id};
                    $timer->event->();
                } else {
                    DEBUG && say "Got an timer($timer) to move from depth($depth) to depth(".($depth - 1).")";

                    my $t   = $timer->expiry;
                    my $exp = $depth;

                    while ($exp < DEPTH) {
                        my $e1 = (10 ** $exp);
                        my $e2 = ($e1 / 10);

                        if (DEBUG) {
                            say sprintf "t(%d) (e: %d e-1: %d)", $t, $e1, $e2;
                            say sprintf "((%d %% %d) - (%d %% %d)) / %d", $t, $e1, $t, $e2, $e2;
                            say sprintf "((%d) - (%d)) / %d", $t % $e1, $t % $e2, $e2;
                            say sprintf "%d / %d", ($t % $e1) - ($t % $e2), $e2;
                            say sprintf "%d", (($t % $e1) - ($t % $e2)) / $e2;
                        }

                        my $x = (($t % $e1) - ($t % $e2)) / $e2;
                        if ($x == 0) {
                            DEBUG && say "x($x) == 0, so dec exp($exp)";
                            $exp--;
                            next;
                        }

                        my $next_index = (($exp - 1) * 10) + $x;
                        DEBUG && say "Moving timer($timer) to index($next_index)";
                        push $wheel[$next_index]->@* => $timer;
                        $timer_count++;
                        # Update tracking with new bucket index
                        $timers_by_id{$timer->id}{bucket_index} = $next_index;
                        last;
                    }
                }
            }
        } else {
            DEBUG && say "no timers to check ...";
        }
    }

    method calculate_first_index_for_time ($t) {
        DEBUG && say "Calculating index for time($t)";
        return $t if $t < 10;

        my $exp = 1;
        while ($exp < DEPTH) {
            my $e1 = (10 ** $exp);
            if ($t < $e1) {
                my $e2 = ($e1 / 10);
                if (DEBUG) {
                    say sprintf "t: %d => (e: %d e-1: %d)", $t, $e1, $e2;
                    say sprintf "((%d %% %d) - (%d %% %d)) / %d", $t, $e1, $t, $e2, $e2;
                    say sprintf "((%d) - (%d)) / %d", $t % $e1, $t % $e2, $e2;
                    say sprintf "%d / %d", ($t % $e1) - ($t % $e2), $e2;
                    say sprintf "%d", (($t % $e1) - ($t % $e2)) / $e2;

                    say sprintf "(%d - 1) * 10", $exp;
                    say sprintf "(%d)", (($exp - 1) * 10);
                }
                my $index = (($exp - 1) * 10) + ((($t % $e1) - ($t % $e2)) / $e2);
                DEBUG && say sprintf "found index: %d", $index;
                return $index;
            } else {
                $exp++;
            }
        }
        Error->throw(
            message => "Timer wheel time overflow",
            hint => "Time value $t exceeds maximum supported time (10^" . DEPTH . ")"
        );
    }

    method calculate_timeout_for_index ($index) {
        DEBUG && say "Calculating timeout for index($index)";
        return $index if $index < 10;
        if (DEBUG) {
            say "index % 10 = ",($index % 10);
            say "index / 10 = ",int($index / 10);
            say "timeout = ",(($index % 10) * (10 ** int($index / 10)));
        }
        return (($index % 10) * (10 ** int($index / 10)));
    }

    method find_next_timeout {
        my $min_expiry;
        foreach my $bucket (@wheel) {
            foreach my $timer (@$bucket) {
                if (!defined $min_expiry || $timer->expiry < $min_expiry) {
                    $min_expiry = $timer->expiry;
                }
            }
        }
        return $min_expiry;
    }

    method add_timer($timer) {
        Error->throw(
            message => "Timer wheel capacity exceeded",
            hint => "Maximum number of timers (" . MAX_TIMERS . ") reached. Cannot add more timers."
        ) if $timer_count >= MAX_TIMERS;

        # Calculate bucket based on delta from current wheel time
        # This ensures timers added during callbacks go to the right bucket
        my $current_time = $state->time;
        my $delta = $timer->expiry - $current_time;

        if ($delta <= 0) {
            Error->throw(
                message => "Cannot add timer in the past",
                hint => "Timer expiry ($timer->expiry) must be greater than current wheel time ($current_time)"
            );
        }

        my $index = $self->calculate_first_index_for_time( $delta );
        DEBUG && say "add_timer: expiry=",$timer->expiry," current=$current_time delta=$delta index=$index";
        push @{$wheel[$index]} => $timer;
        $timer_count++;

        # Track for cancellation
        $timers_by_id{$timer->id} = {
            timer => $timer,
            bucket_index => $index
        };
    }

    method cancel_timer($timer_id) {
        my $info = delete $timers_by_id{$timer_id};
        return 0 unless $info;  # Not found

        my $bucket = $wheel[$info->{bucket_index}];
        my $timer = $info->{timer};

        # Remove from bucket
        @$bucket = grep { $_->id ne $timer_id } @$bucket;
        $timer_count--;

        return 1;  # Success
    }

    method timer_count { $timer_count }

    method dump_wheel {

        say "-- wheel -----------------------------------------------------------";
        say "       | ".(join ' | ' => map { sprintf '%03d' => $_ } 0 ..  9).' |';

        foreach my $i ( 0 .. (DEPTH - 1) ) {
            my @line;
            push @line => "10e0${i}";
            foreach my $j ( 0 .. 9 ) {
                my $idx   = ($i * 10) + $j;
                my $count = scalar $wheel[$idx]->@*;

                push @line => sprintf "\e[38;5;%dm%03d\e[0m" => $count, $count;
            }
            say ' ',(shift @line),' | ',(join ' | ' => @line),' |';
        }

        say "--------------------------------------------------------------------";
        say "state = ",$state;
        say "      | ",(join ', ', $state->changes);
        say "--------------------------------------------------------------------";
        foreach my ($i, $x) (indexed @wheel[0 .. 30]) {
            if (scalar @$x > 5) {
                say((sprintf 'wheel[%03d]' => $i)."[",(join ', ' => @{$x}[0 .. 3]),"], ...");
            } else {
                say((sprintf 'wheel[%03d]' => $i)."[",(join ', ' => @$x),"]");
            }
        }
        say "...";
        say "--------------------------------------------------------------------";
    }
}
