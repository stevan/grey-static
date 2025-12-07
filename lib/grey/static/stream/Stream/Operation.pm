
use v5.40;
use experimental qw[ class ];

class Stream::Operation {}

class Stream::Operation::Node :isa(Stream::Operation) {
    method     next { ... }
    method has_next { ... }
}

class Stream::Operation::Terminal :isa(Stream::Operation) {
    method apply { ... }
}
