
use v5.40;
use experimental qw[ class try ];

class Flow::Executor {
    field $next :param :reader = undef;

    field @callbacks;

    ADJUST {
        # Validate $next if provided via constructor
        # This ensures ALL assignments to $next go through validation
        $self->set_next($next);
    }

    method set_next ($n) {
        return $next = undef unless defined $n;

        # Check if setting this would create a cycle
        my $current = $n;
        my %seen;
        my $self_addr = refaddr($self);

        while ($current) {
            my $addr = refaddr($current);
            if ($addr == $self_addr) {
                die "Circular executor chain detected: setting next would create a cycle\n";
            }
            last if $seen{$addr}++;  # Stop if we hit an existing cycle (not involving $self)
            $current = $current->next;
        }

        $next = $n;
    }

    method remaining { scalar @callbacks }
    method is_done   { (scalar @callbacks == 0) ? 1 : 0 }

    method next_tick ($f) {
        push @callbacks => $f
    }

    method tick {
        return $next unless @callbacks;
        my @to_run = @callbacks;
        @callbacks = ();
        while (my $f = shift @to_run) {
            try {
                $f->();
            }
            catch ($e) {
                # Preserve remaining callbacks on exception
                unshift @callbacks, @to_run;
                die $e;  # Re-throw
            }
        }
        return $next;
    }

    method find_next_undone {
        my $current = $self;

        while ($current) {
            return $current if $current->remaining > 0;
            $current = $current->next;
        }
        return undef;
    }

    method run {
        my $t = $self;

        while (blessed $t && $t isa Flow::Executor) {
            $t = $t->tick;
            if (!$t) {
                $t = $self->find_next_undone;
            }
        }
        return;
    }

    method shutdown {
        $self->diag;
    }

    method collect_all {
        my @all;
        my $current = $self;

        while ($current) {
            push @all => $current;
            $current = $current->next;
        }

        return @all;
    }

    method diag {
        my @all = $self->collect_all;
        # TODO: do something here ...
    }

    method to_string {
        sprintf 'Executor[%d]' => refaddr $self;
    }
}
