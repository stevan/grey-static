
use v5.42;
use utf8;
use experimental qw[ class keyword_any keyword_all ];
use grey::static::error;

class Map {
    use overload (
        '""' => sub ($self, @) { $self->to_string() },
        fallback => 1,
    );

    field $entries :param;

    ADJUST {
        Error->throw("entries must be a hashref") unless ref $entries eq 'HASH';
        $entries = {%$entries};  # defensive copy
    }

    # --------------------------------------------------------------------------
    # Class methods (constructors)
    # --------------------------------------------------------------------------

    sub of ($class, @pairs) {
        Error->throw("of() requires an even number of arguments")
            if @pairs % 2 != 0;
        my %hash = @pairs;
        return $class->new(entries => \%hash);
    }

    sub empty ($class) {
        return $class->new(entries => {});
    }

    # --------------------------------------------------------------------------
    # Core operations
    # --------------------------------------------------------------------------

    method size () {
        return scalar keys %$entries;
    }

    method is_empty () {
        return $self->size() == 0;
    }

    method get ($key) {
        return Option->new() unless exists $entries->{$key};
        return Option->new(some => $entries->{$key});
    }

    method contains_key ($key) {
        return exists $entries->{$key};
    }

    method contains_value ($value) {
        return any { $_ eq $value } values %$entries;
    }

    method put ($key, $value) {
        my %new_entries = %$entries;
        $new_entries{$key} = $value;
        return Map->new(entries => \%new_entries);
    }

    method remove (@keys) {
        my %new_entries = %$entries;
        delete $new_entries{$_} for @keys;
        return Map->new(entries => \%new_entries);
    }

    method keys () {
        require Set;
        return Set->new(items => [keys %$entries]);
    }

    method values () {
        require List;
        return List->new(items => [values %$entries]);
    }

    method entries () {
        require List;
        my @pairs = map { [$_, $entries->{$_}] } keys %$entries;
        return List->new(items => \@pairs);
    }

    # --------------------------------------------------------------------------
    # Functional operations
    # --------------------------------------------------------------------------

    method map ($bifunction) {
        Error->throw("map requires a BiFunction") unless defined $bifunction;
        my %new_entries = map { $_ => $bifunction->apply($_, $entries->{$_}) } keys %$entries;
        return Map->new(entries => \%new_entries);
    }

    method map_keys ($function) {
        Error->throw("map_keys requires a Function") unless defined $function;
        my %new_entries = map { $function->apply($_) => $entries->{$_} } keys %$entries;
        return Map->new(entries => \%new_entries);
    }

    method map_entries ($bifunction) {
        Error->throw("map_entries requires a BiFunction") unless defined $bifunction;
        my %new_entries;
        for my $key (keys %$entries) {
            my ($new_key, $new_value) = $bifunction->apply($key, $entries->{$key});
            $new_entries{$new_key} = $new_value;
        }
        return Map->new(entries => \%new_entries);
    }

    method grep ($bipredicate) {
        Error->throw("grep requires a BiPredicate") unless defined $bipredicate;
        my %new_entries;
        for my $key (keys %$entries) {
            $new_entries{$key} = $entries->{$key}
                if $bipredicate->test($key, $entries->{$key});
        }
        return Map->new(entries => \%new_entries);
    }

    method foreach ($biconsumer) {
        Error->throw("foreach requires a BiConsumer") unless defined $biconsumer;
        for my $key (keys %$entries) {
            $biconsumer->accept($key, $entries->{$key});
        }
        return;
    }

    method find ($bipredicate) {
        Error->throw("find requires a BiPredicate") unless defined $bipredicate;
        for my $key (keys %$entries) {
            return Option->new(some => [$key, $entries->{$key}])
                if $bipredicate->test($key, $entries->{$key});
        }
        return Option->new();
    }

    method reduce ($initial, $trifunction) {
        Error->throw("reduce requires a function") unless defined $trifunction;
        my $acc = $initial;
        for my $key (keys %$entries) {
            $acc = $trifunction->($acc, $key, $entries->{$key});
        }
        return $acc;
    }

    # --------------------------------------------------------------------------
    # Conversion
    # --------------------------------------------------------------------------

    method to_stream () {
        my @pairs = map { [$_, $entries->{$_}] } keys %$entries;
        return Stream->from_array(\@pairs);
    }

    method to_hash () {
        return {%$entries};
    }

    method to_string () {
        my @pairs = map { "$_=>" . (defined $entries->{$_} ? $entries->{$_} : 'undef') }
                    sort keys %$entries;
        my $contents = join(', ', @pairs);
        return "Map{$contents}";
    }
}
