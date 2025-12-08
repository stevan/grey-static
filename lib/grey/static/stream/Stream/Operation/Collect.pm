
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Collect :isa(Stream::Operation::Terminal) {
    field $source      :param;
    field $accumulator :param;

    method apply {
        while ($source->has_next) {
            my $next = $source->next;
            #say "Calling accumulator apply on $next";
            $accumulator->accept($next);
        }
        return $accumulator->result;
    }
}

