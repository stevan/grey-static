
use v5.40;
use experimental qw[ class ];

class Flow::Subscription {
    field $publisher  :param :reader;
    field $subscriber :param :reader;
    field $executor   :param :reader;

    field $requested = 0;
    field @buffer;

    method drain_buffer {
        while (@buffer && $requested) {
            $requested--;
            my $next = shift @buffer;
            $executor->next_tick(sub {
                $self->on_next($next);
            });
        }
    }


    method request ($n) {
        $requested += $n;
        if (@buffer) {
            $executor->next_tick(sub {
                $self->drain_buffer;
            });
        }
    }

    method cancel {
        $executor->next_tick(sub {
            $publisher->unsubscribe( $self );
        });
    }

    method offer ($e) {
        push @buffer => $e;
        if ($requested) {
            $executor->next_tick(sub {
                $self->drain_buffer;
            });
        }
    }

    method on_unsubscribe {
        $executor->next_tick(sub {
            $subscriber->on_unsubscribe;
        });
    }

    method on_next ($e) {
        $executor->next_tick(sub {
            $subscriber->on_next( $e );
        });
    }

    method on_completed {
        $executor->next_tick(sub {
            $subscriber->on_completed;
        });
    }

    method on_error ($e) {
        $executor->next_tick(sub {
            $subscriber->on_error( $e );
        });
    }

    method to_short {
        sprintf '%d@(%s,%s)' => refaddr $self,
        map { (split '::' => $_)[-1] } blessed $publisher, blessed $subscriber;
    }

    method to_string {
        sprintf 'Subscription[%d]<%s,%s>' => refaddr $self,
        map { (split '::' => $_)[-1] } blessed $publisher, blessed $subscriber;
    }
}
