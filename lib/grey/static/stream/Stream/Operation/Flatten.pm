
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Flatten :isa(Stream::Operation::Node) {
    field $source  :param;
    field $flatten :param;

    field $next;
    field @stack;

    method next { shift @stack }

    method has_next {
        return true if @stack;
        while ($source->has_next) {
            push @stack => $flatten->apply( $source->next );
            return true if @stack;
        }
        return false;
    }
}
