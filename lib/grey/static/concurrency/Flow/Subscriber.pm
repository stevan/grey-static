
use v5.40;
use experimental qw[ class ];

class Flow::Subscriber {
    field $request_size :param :reader = 1;
    field $consumer     :param :reader;

    field $subscription;
    field $count;

    method on_subscribe ($s) {
        $subscription = $s;
        $count        = $request_size;
        $subscription->request( $request_size );
    }

    method on_unsubscribe {
        $subscription = undef;
    }

    method on_next ($e) {
        if (--$count <= 0) {
            $count = $request_size;
            $subscription->request( $request_size );
        }
        $consumer->accept( $e );
    }

    method on_completed {
        $subscription->cancel if $subscription;
    }

    method on_error ($e) {
        $subscription->cancel if $subscription;
    }

    method to_string {
        sprintf 'Subscriber[%d]' => refaddr $self;
    }
}
