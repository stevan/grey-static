
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Stream::Source::FromRange :isa(Stream::Source) {
    field $start :param :reader;
    field $end   :param :reader;
    field $step  :param :reader = 1;

    field $current;
    ADJUST {
        Error->throw(
            message => "Invalid 'start' parameter for Stream::Source::FromRange",
            hint => "Expected a number, got: " . (defined $start ? "'$start'" : "undef")
        ) unless defined $start && $start =~ /^-?\d+(?:\.\d+)?$/;

        Error->throw(
            message => "Invalid 'end' parameter for Stream::Source::FromRange",
            hint => "Expected a number, got: " . (defined $end ? "'$end'" : "undef")
        ) unless defined $end && $end =~ /^-?\d+(?:\.\d+)?$/;

        Error->throw(
            message => "Invalid 'step' parameter for Stream::Source::FromRange",
            hint => "Step must be a non-zero number, got: " . (defined $step ? "'$step'" : "undef")
        ) unless defined $step && $step =~ /^-?\d+(?:\.\d+)?$/ && $step != 0;

        $current = $start;
    }

    method next {
        my $next = $current;
        $current += $step;
        return $next;
    }

    method has_next { $current <= $end }
}
