
use v5.40;
use experimental qw[ class ];

class Stream::Source::FromArray :isa(Stream::Source) {
    field $array :param :reader;
    field $index = 0;

    method     next { $array->[$index++]  }
    method has_next { $index < scalar $array->@* }
}
