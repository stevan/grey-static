
use v5.42;
use experimental qw[ class ];

class Flow::Operation::Take :isa(Flow::Operation) {
    field $n :param;      # Number of elements to take
    field $count = 0;     # Elements taken so far
    field $completed = 0; # Flag to prevent further processing

    method apply ($e) {
        return if $completed;  # Don't process if already completed

        if ($count < $n) {
            $count++;
            $self->submit($e);

            # After taking N elements, complete and cancel upstream
            if ($count >= $n) {
                $completed = 1;
                $self->executor->next_tick(sub {
                    $self->downstream->on_completed if $self->downstream;
                    $self->upstream->cancel if $self->upstream;
                });
            }
        }
    }

    # Override on_next to avoid requesting more after completion
    method on_next ($e) {
        return if $completed;

        if ($self->upstream) {
            $self->upstream->request(1) unless $completed;
        }

        $self->executor->next_tick(sub {
            $self->apply($e) unless $completed;
        });
    }
}
