
use v5.42;
use experimental qw[ class try ];

class Promise {
    use constant IN_PROGRESS => 'in progress';
    use constant RESOLVED    => 'resolved';
    use constant REJECTED    => 'rejected';

    field $executor :param;

    field $result;
    field $error;

    field $status;
    field @resolved;
    field @rejected;

    ADJUST {
        $executor isa Executor || die 'The `executor` param must be a Executor';

        $status = IN_PROGRESS;
    }

    method status   { $status }
    method result   { $result }
    method error    { $error  }
    method executor { $executor }

    method is_in_progress { $status eq IN_PROGRESS }
    method is_resolved    { $status eq RESOLVED    }
    method is_rejected    { $status eq REJECTED    }

    my sub wrap ($p, $then) {
        return sub ($value) {
            my ($result, $error);
            try {
                $result = $then->( $value );
            } catch ($e) {
                chomp $e;
                $error = $e;
            }

            if ($error) {
                $p->reject( $error );
                return;
            }

            if ( $result isa Promise ) {
                $result->then(
                    sub { $p->resolve(@_); () },
                    sub { $p->reject(@_);  () },
                );
            }
            else {
                $p->resolve( $result );
            }
            return;
        };
    }

    method then ($then, $catch=undef) {
        my $p = $self->new( executor => $executor );
        push @resolved => wrap( $p, $then );
        push @rejected => wrap( $p, $catch // sub ($e) { die "$e\n" } );
        $self->_notify unless $self->is_in_progress;
        $p;
    }

    method resolve ($_result) {
        $status eq IN_PROGRESS || die "Cannot resolve. Already ($status)";

        $status = RESOLVED;
        $result = $_result;
        $self->_notify;
        $self;
    }

    method reject ($_error) {
        $status eq IN_PROGRESS || die "Cannot reject. Already ($status)";

        $status = REJECTED;
        $error  = $_error;
        $self->_notify;
        $self;
    }

    method _notify {

        my ($value, @cbs);

        if ($self->is_resolved) {
            $value = $result;
            @cbs   = @resolved;
        }
        elsif ($self->is_rejected) {
            $value = $error;
            @cbs   = @rejected;
        }
        else {
            die "Bad Notify State ($status)";
        }

        @resolved = ();
        @rejected = ();

        if ($executor) {
            $executor->next_tick(sub { $_->($value) foreach @cbs });
        }
        else {
            $_->($value) foreach @cbs;
        }
    }


}

1;

__END__

=pod

=cut
