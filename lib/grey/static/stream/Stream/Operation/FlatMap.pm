
use v5.42;
use experimental qw[ class ];

class Stream::Operation::FlatMap :isa(Stream::Operation::Node) {
    field $source :param :reader;
    field $mapper :param :reader;

    field $current;
    field $next;

    method next { $next }

    method has_next {
        #say "-> calling has_next ...";
        $self->_populate_current
            or return false
                if not defined $current;

        #say "Checking Current: $current";
        while (true) {
            if ($current->has_next) {
                #say "got current->next";
                $next = $current->next;
                #say "GOT next: $next";
                return true;
            }
            else {
                #say "current is exhausted, look again ... ";
                $self->_populate_current
                    or return false;
            }
        }
    }

    method _populate_current {
        if ($source->has_next) {
            #say "fetch current";
            my $x = $source->next;
            #say "GOT source->next: $x";
            my $s = $mapper->apply( $x );
            #say "GOT source->next: f($x) -> $s";
            $current = $s->source;
            #say "GOT Current: $current";
            return true;
        }
        else {
            #say "all done!";
            return false;
        }
    }
}

