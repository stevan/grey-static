
use v5.42;
use experimental qw[ class ];

class Flow::Operation::Skip :isa(Flow::Operation) {
    field $n :param;      # Number of elements to skip
    field $skipped = 0;   # Elements skipped so far

    method apply ($e) {
        if ($skipped < $n) {
            # Still skipping, don't submit
            $skipped++;
        } else {
            # Done skipping, submit all remaining elements
            $self->submit($e);
        }
    }
}
