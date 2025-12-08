
use v5.42;
use experimental qw[ class ];

package Stream::Collectors {

    sub ToList { Stream::Collectors::Accumulator->new }

    sub JoinWith($, $sep='') {
        Stream::Collectors::Accumulator->new(
            finisher => sub (@acc) { join $sep, @acc }
        )
    }

}

class Stream::Collectors::Accumulator {
    field $finisher :param = undef;
    field @acc;

    method accept ($arg) { push @acc => $arg; return; }

    method result { $finisher ? $finisher->( @acc ) : @acc }
}
