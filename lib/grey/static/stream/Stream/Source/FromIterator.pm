
use v5.42;
use experimental qw[ class ];
use grey::static::error;
use Scalar::Util qw(blessed);

class Stream::Source::FromIterator :isa(Stream::Source) {
    field $seed     :param;
    field $next     :param;
    field $has_next :param;

    field $current;
    ADJUST {
        Error->throw(
            message => "Invalid 'next' parameter for Stream::Source::FromIterator",
            hint => "Expected a Function object or CODE reference"
        ) unless (blessed($next) && $next->can('apply')) || ref($next) eq 'CODE';

        if (defined $has_next) {
            Error->throw(
                message => "Invalid 'has_next' parameter for Stream::Source::FromIterator",
                hint => "Expected a Predicate object or CODE reference"
            ) unless (blessed($has_next) && $has_next->can('test')) || ref($has_next) eq 'CODE';
        }
        $current = $seed;
    }

    method     next { $current = $next->apply($current) }
    method has_next {
        return true unless defined $has_next;
        return $has_next->test($current);
    }
}
