
use v5.42;
use experimental qw[ class ];
use grey::static::error;

class Stream::Source::FromArray :isa(Stream::Source) {
    field $array :param :reader;
    field $index = 0;

    ADJUST {
        Error->throw(
            message => "Invalid 'array' parameter for Stream::Source::FromArray",
            hint => "Expected an ARRAY reference, got: " . (ref($array) || 'scalar')
        ) unless ref($array) eq 'ARRAY';
    }

    method     next { $array->[$index++]  }
    method has_next { $index < scalar $array->@* }
}
