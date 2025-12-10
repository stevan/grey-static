
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class List {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $items :param;

    ADJUST {
        # Validate and copy the items arrayref to ensure ownership
        Error->throw("items must be an arrayref") unless ref $items eq 'ARRAY';
        $items = [@$items];  # defensive copy
    }

    # --------------------------------------------------------------------------
    # Class methods (constructors)
    # --------------------------------------------------------------------------

    sub of {
        my ($class, @values) = @_;
        return List->new(items => [@values]);
    }

    sub empty {
        my ($class) = @_;
        return List->new(items => []);
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

    method at ($index) {
        Error->throw("Index out of bounds: $index")
            if $index < 0 || $index >= $self->size();
        return $items->[$index];
    }

    method first () {
        Error->throw("Cannot get first element of empty list")
            if $self->is_empty();
        return $items->[0];
    }

    method last () {
        Error->throw("Cannot get last element of empty list")
            if $self->is_empty();
        return $items->[-1];
    }

    method slice ($start, $end) {
        Error->throw("Invalid slice range: start=$start, end=$end")
            if $start < 0 || $end < $start || $end > $self->size();
        return List->new(items => [@$items[$start .. $end - 1]]);
    }

    method push (@values) {
        return List->new(items => [@$items, @values]);
    }

    method pop () {
        Error->throw("Cannot pop from empty list")
            if $self->is_empty();
        my @new_items = @$items[0 .. $#$items - 1];
        return [$items->[-1], List->new(items => \@new_items)];
    }

    method shift () {
        Error->throw("Cannot shift from empty list")
            if $self->is_empty();
        my @new_items = @$items[1 .. $#$items];
        return [$items->[0], List->new(items => \@new_items)];
    }

    method unshift (@values) {
        return List->new(items => [@values, @$items]);
    }

    method reverse () {
        return List->new(items => [reverse @$items]);
    }

    method sort ($comparator = undef) {
        if (defined $comparator) {
            # Comparator is expected to be a Comparator object with compare($a, $b)
            my @sorted = sort { $comparator->compare($a, $b) } @$items;
            return List->new(items => \@sorted);
        } else {
            # Default sort
            my @sorted = sort @$items;
            return List->new(items => \@sorted);
        }
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        return List->new(items => [ map { $function->apply($_) } @$items ]);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        return List->new(items => [ grep { $predicate->test($_) } @$items ]);
    }

    method reduce ($initial, $bifunction) {
        Error->throw("reduce requires a BiFunction") unless defined $bifunction;
        my $acc = $initial;
        for my $item (@$items) {
            $acc = $bifunction->apply($acc, $item);
        }
        return $acc;
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
        return Option->new(); # None
    }

    method contains ($value) {
        return any { $_ eq $value } @$items;
    }

    method any ($predicate) {
        Error->throw("any requires a Predicate") unless defined $predicate;
        return any { $predicate->test($_) } @$items;
    }

    method all ($predicate) {
        Error->throw("all requires a Predicate") unless defined $predicate;
        return all { $predicate->test($_) } @$items;
    }

    method none ($predicate) {
        Error->throw("none requires a Predicate") unless defined $predicate;
        return !any { $predicate->test($_) } @$items;
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
        return "List[$contents]";
    }
}
