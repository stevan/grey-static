
use v5.40;
use experimental qw[ class ];

use Flow::Subscription;

class Flow::Operation {
    field $executor   :reader;
    field $downstream :reader;
    field $upstream   :reader;

    field @buffer;

    ADJUST {
        $executor = Flow::Executor->new;
    }

    method apply ($e) { ... }

    method submit ($value) {
        push @buffer => $value;
        if ($downstream) {
            while (@buffer && $downstream) {
                my $next = shift @buffer;
                $executor->next_tick(sub {
                    $downstream->offer( $next )
                });
            }
        }
    }

    method subscribe ($subscriber) {
        $downstream = Flow::Subscription->new(
            publisher  => $self,
            subscriber => $subscriber,
            executor   => $executor,
        );

        $executor->next_tick(sub {
            $subscriber->on_subscribe( $downstream );
        });
    }

    method unsubscribe ($downstream) {
        $upstream->cancel;
        $upstream = undef;
    }

    method on_subscribe ($s) {
        $upstream = $s;
        $upstream->executor->set_next( $executor );
        $upstream->request(1);
    }

    method on_unsubscribe {
        $executor->next_tick(sub {
            $downstream->on_unsubscribe;
        });
    }

    method on_next ($e) {
        $upstream->request(1);
        $executor->next_tick(sub {
            $self->apply( $e );
        });
    }

    method on_completed {
        $executor->next_tick(sub {
            $downstream->on_completed;
        });
    }

    method on_error ($e) {
        $executor->next_tick(sub {
            $downstream->on_error;
        });
    }

    method to_string {
        sprintf '%s[%d]' => (split '::' => __CLASS__)[-1], refaddr $self
    }
}

