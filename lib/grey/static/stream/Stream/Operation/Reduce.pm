
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Reduce :isa(Stream::Operation::Terminal) {
    field $source  :param;
    field $initial :param;
    field $reducer :param;

    method apply {
        my $acc = $initial;
        while ($source->has_next) {
            $acc = $reducer->apply($source->next, $acc);
        }
        return $acc;
    }
}

