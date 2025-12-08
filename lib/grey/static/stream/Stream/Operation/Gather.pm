
use v5.42;
use experimental qw[ class ];

class Stream::Operation::Gather :isa(Stream::Operation::Node) {
    field $source :param;
    field $init   :param;
    field $reduce :param;
    field $finish :param = undef;

    field $acc;
    field $next;

    ADJUST {
        $acc = $init->get;
    }

    method next { $finish ? $finish->apply($next) : $next }

    method has_next {
        $next = undef;

        my $seen = 0;
        while ($source->has_next) {
            $seen++;
            my $candidate = $source->next;
            #say "NEXT: $candidate";
            if ( $reduce->apply($candidate, $acc) ) {
                #say "IS DONE!";
                $next = $acc;
                $acc  = $init->get;
                return true;
            }
        }

        #say "!! Out of elements !! next(".($next // '~').") seen($seen)";
        if (!(defined $next) && $seen != 0) {
            #say "Found accumulated results! seen($seen) acc(".(join ', ' => @$acc).")";
            $next = $acc;
            return true;
        }

        #say "Okay, all done!";
        return false;
    }
}
