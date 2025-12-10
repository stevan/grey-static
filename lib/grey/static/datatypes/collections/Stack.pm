
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Stack {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $items :param;

    ADJUST {
        Error->throw("items must be an arrayref") unless ref $items eq 'ARRAY';
        $items = [@$items];  # defensive copy
    }

    # --------------------------------------------------------------------------
    # Class methods (constructors)
    # --------------------------------------------------------------------------

    sub of ($class, @values) {
        return $class->new(items => [@values]);
    }

    sub empty ($class) {
        return $class->new(items => []);
    }

    # --------------------------------------------------------------------------
    # Core operations
    # --------------------------------------------------------------------------

    method size () {
        return scalar @$items;
    }

    method is_empty () {
        return $self->size() == 0;
    }

    method push (@values) {
        return Stack->new(items => [@$items, @values]);
    }

    method pop () {
        Error->throw("Cannot pop from empty stack")
            if $self->is_empty();
        my @new_items = @$items[0 .. $#$items - 1];
        return [$items->[-1], Stack->new(items => \@new_items)];
    }

    method peek () {
        return Option->new() if $self->is_empty();
        return Option->new(some => $items->[-1]);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        return Stack->new(items => [ map { $function->apply($_) } @$items ]);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        return Stack->new(items => [ grep { $predicate->test($_) } @$items ]);
    }

    method foreach ($consumer) {
        Error->throw("foreach requires a Consumer") unless defined $consumer;
        for my $item (@$items) {
            $consumer->accept($item);
        }
        return;
    }

    method find ($predicate) {
        Error->throw("find requires a Predicate") unless defined $predicate;
        for my $item (@$items) {
            return Option->new(some => $item) if $predicate->test($item);
        }
        return Option->new();
    }

    method contains ($value) {
        return any { $_ eq $value } @$items;
    }

    # --------------------------------------------------------------------------
    # Conversion
    # --------------------------------------------------------------------------

    method to_stream () {
        return Stream->from_array([@$items]);
    }

    method to_array () {
        return [@$items];
    }

    method to_list () {
        return @$items;
    }

    method to_string () {
        my $contents = join(', ', map { defined $_ ? $_ : 'undef' } @$items);
        return "Stack[$contents]";
    }
}
