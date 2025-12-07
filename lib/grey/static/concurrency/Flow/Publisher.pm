
use v5.40;
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
            $executor->next_tick(sub {
                $subscription->offer( $next )
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

    method close {
        if ($subscription) {
            if (@buffer) {
                @buffer = ();
            }
            $executor->next_tick(sub {
                $subscription->on_completed;
            });

            $executor->run;
        }
        $executor->shutdown;
    }

    method to_string {
        sprintf 'Publisher[%d]' => refaddr $self;
    }
}
