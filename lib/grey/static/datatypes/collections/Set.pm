
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Set {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $items :param;

    ADJUST {
        Error->throw("items must be an arrayref") unless ref $items eq 'ARRAY';
        # Create hash from array for uniqueness
        my %unique = map { $_ => 1 } @$items;
        $items = \%unique;
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
        return scalar keys %$items;
    }

    method is_empty () {
        return $self->size() == 0;
    }

    method contains ($value) {
        return exists $items->{$value};
    }

    method add (@values) {
        my %new_items = %$items;
        $new_items{$_} = 1 for @values;
        return Set->new(items => [keys %new_items]);
    }

    method remove (@values) {
        my %new_items = %$items;
        delete $new_items{$_} for @values;
        return Set->new(items => [keys %new_items]);
    }

    method union ($other_set) {
        Error->throw("union requires a Set") unless $other_set isa Set;
        my %new_items = %$items;
        $new_items{$_} = 1 for $other_set->to_list();
        return Set->new(items => [keys %new_items]);
    }

    method intersection ($other_set) {
        Error->throw("intersection requires a Set") unless $other_set isa Set;
        my @common = grep { $other_set->contains($_) } keys %$items;
        return Set->new(items => \@common);
    }

    method difference ($other_set) {
        Error->throw("difference requires a Set") unless $other_set isa Set;
        my @diff = grep { !$other_set->contains($_) } keys %$items;
        return Set->new(items => \@diff);
    }

    method is_subset ($other_set) {
        Error->throw("is_subset requires a Set") unless $other_set isa Set;
        return all { $other_set->contains($_) } keys %$items;
    }

    method is_superset ($other_set) {
        Error->throw("is_superset requires a Set") unless $other_set isa Set;
        return $other_set->is_subset($self);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($function) {
        Error->throw("map requires a Function") unless defined $function;
        my @values = map { $function->apply($_) } keys %$items;
        return Set->new(items => \@values);
    }

    method grep ($predicate) {
        Error->throw("grep requires a Predicate") unless defined $predicate;
        my @values = grep { $predicate->test($_) } keys %$items;
        return Set->new(items => \@values);
    }

    method foreach ($consumer) {
        Error->throw("foreach requires a Consumer") unless defined $consumer;
        for my $item (keys %$items) {
            $consumer->accept($item);
        }
        return;
    }

    method find ($predicate) {
        Error->throw("find requires a Predicate") unless defined $predicate;
        for my $item (keys %$items) {
            return Option->new(some => $item) if $predicate->test($item);
        }
        return Option->new();
    }

    method any ($predicate) {
        Error->throw("any requires a Predicate") unless defined $predicate;
        return any { $predicate->test($_) } keys %$items;
    }

    method all ($predicate) {
        Error->throw("all requires a Predicate") unless defined $predicate;
        return all { $predicate->test($_) } keys %$items;
    }

    method none ($predicate) {
        Error->throw("none requires a Predicate") unless defined $predicate;
        return !any { $predicate->test($_) } keys %$items;
    }

    # --------------------------------------------------------------------------
    # Conversion
    # --------------------------------------------------------------------------

    method to_stream () {
        return Stream->from_array([keys %$items]);
    }

    method to_array () {
        return [keys %$items];
    }

    method to_list () {
        return keys %$items;
    }

    method to_string () {
        my $contents = join(', ', sort keys %$items);
        return "Set{$contents}";
    }
}
