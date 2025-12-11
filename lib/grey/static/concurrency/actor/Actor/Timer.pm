use v5.42;
use experimental qw[ class ];

# Timer wrapper that provides Yakt-style API backed by ScheduledExecutor
# Bridges: $context->schedule(after => 1.5, callback => sub{}) API
# To:      $executor->schedule_delayed($callback, $delay_ms) API
class Actor::Timer {
    field $executor :param;
    field $timer_id :param;
    field $cancelled = false;

    method timer_id  { $timer_id  }
    method cancelled { $cancelled }

    method cancel {
        return if $cancelled;
        $cancelled = true;
        $executor->cancel_scheduled($timer_id);
    }
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Actor::Timer - Timer object returned by Actor scheduling operations

=head1 SYNOPSIS

    use grey::static qw[ concurrency::actor ];

    # In an actor signal handler:
    method on_started :Signal(Actor::Signals::Started) ($context, $signal) {
        # Schedule a timer (returns Actor::Timer)
        my $timer = $context->schedule(
            after    => 5.0,           # seconds (float)
            callback => sub {
                $context->self->send(Timeout->new);
            }
        );

        # Cancel if needed
        $timer->cancel;
    }

=head1 DESCRIPTION

C<Actor::Timer> is a timer handle returned by C<< $context->schedule() >>.
It wraps the underlying C<ScheduledExecutor> timer ID and provides a clean
object-oriented interface for cancellation.

This class bridges the Yakt-style timer API (seconds-based, object return)
with the grey::static C<ScheduledExecutor> API (milliseconds-based, ID return).

=head1 CONSTRUCTOR

Not typically constructed directly. Created by C<ActorSystem> when
C<< $context->schedule() >> is called.

=head1 METHODS

=head2 cancel

    $timer->cancel;

Cancels the timer, preventing the callback from executing. Safe to call
multiple times - subsequent calls are no-ops.

B<Returns:> Nothing.

=head2 cancelled

    if ($timer->cancelled) { ... }

Returns true if the timer has been cancelled.

B<Returns:> Boolean indicating cancellation status.

=head2 timer_id

    my $id = $timer->timer_id;

Returns the underlying C<ScheduledExecutor> timer ID. Primarily for
debugging and testing.

B<Returns:> Integer timer ID.

=head1 USAGE NOTES

=over 4

=item *

Timers fire on the actor system's event loop, not in a separate thread.

=item *

Cancelled timers are marked but not immediately removed from the timer
queue. They are cleaned up lazily during normal timer processing.

=item *

The callback closure captures the actor context at scheduling time.
Be mindful of actor lifecycle when scheduling long-duration timers.

=back

=head1 SEE ALSO

L<ActorSystem>, L<Actor::Context>, L<ScheduledExecutor>

=cut
