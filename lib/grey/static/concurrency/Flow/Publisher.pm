
use v5.42;
use experimental qw[ class ];

use Flow::Executor;
use Flow::Subscription;

class Flow::Publisher {
    field $executor     :reader;
    field $subscription :reader;

    field @buffer;

    ADJUST {
        $executor = Flow::Executor->new;
    }

    method drain_buffer {
        while (@buffer && $subscription) {
            my $next = shift @buffer;
            my $sub = $subscription;  # Capture to avoid undefined value if subscription is cleared
            $executor->next_tick(sub {
                $sub->offer( $next ) if $sub;
            });
        }
    }

    method subscribe ($subscriber) {
        $subscription = Flow::Subscription->new(
            publisher  => $self,
            subscriber => $subscriber,
            executor   => $executor,
        );

        $executor->next_tick(sub {
            $subscriber->on_subscribe( $subscription );
        });
    }

    method unsubscribe ($s) {
        $subscription = undef;
        $executor->next_tick(sub {
            $s->on_unsubscribe;
        });
    }

    method submit ($value) {
        push @buffer => $value;
        if ($subscription) {
            $executor->next_tick(sub {
                $self->drain_buffer;
            });
        }
    }

    method start {
        $executor->run;
    }

    method close ($callback = undef) {
        if ($subscription) {
            # Run executor first to complete any pending subscriptions
            $executor->run;

            # Drain any buffered items
            $self->drain_buffer;

            # Then schedule completion
            $executor->next_tick(sub {
                $subscription->on_completed;
                $callback->() if $callback;
            });

            $executor->run;
        }
        elsif ($callback) {
            # No subscription but callback provided
            $callback->();
        }
        $executor->shutdown;
    }

    method to_string {
        sprintf 'Publisher[%d]' => refaddr $self;
    }
}
