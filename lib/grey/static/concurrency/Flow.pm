
use v5.40;
use experimental qw[ class ];

use Flow::Publisher;
use Flow::Subscriber;
use Flow::Subscription;
use Flow::Operation;

use Flow::Operation::Grep;
use Flow::Operation::Map;

class Flow {
    field $source :param :reader;

    field $sink :reader;
    field @ops  :reader;

    sub from ($class, $publisher) {
        my $self = $class->new( source => $publisher );
        return $self;
    }

    method to ($subscriber, %args) {
        if (blessed $subscriber) {
            if ($subscriber isa Flow::Subscriber) {
                $sink = $subscriber;
            }
            elsif ($subscriber isa Consumer) {
                $sink = Flow::Subscriber->new( consumer => $subscriber, %args );
            }
        }
        else {
            $sink = Flow::Subscriber->new(
                consumer => Consumer->new( f => $subscriber ),
                %args
            );
        }
        return $self;
    }

    method map ($f) {
        push @ops => Flow::Operation::Map->new(
            f => blessed $f ? $f : Function->new( f => $f )
        );
        return $self;
    }

    method grep ($f) {
        push @ops => Flow::Operation::Grep->new(
            f => blessed $f ? $f : Predicate->new( f => $f )
        );
        return $self;
    }

    method build {
        my $op = $source;
        foreach my $next (@ops) {
            $op->subscribe( $next );
            $op = $next;
        }
        $op->subscribe( $sink );
        return $source;
    }

    method to_string {
        sprintf 'Flow[%d]' => refaddr $self;
    }
}
