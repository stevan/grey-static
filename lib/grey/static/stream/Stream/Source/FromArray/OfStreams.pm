
use v5.40;
use experimental qw[ class ];

class Stream::Source::FromArray::OfStreams :isa(Stream::Source) {
    field $sources :param;

    field $index = 0;

    method next { $sources->[$index]->next }

    method has_next {
        until ($sources->[$index]->has_next) {
            return false if ++$index > $#{$sources};
        }
        return true;
    }
}

