
use v5.42;
use experimental qw[ class try ];
use grey::static::error;

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
        Error->throw(
            message => "Invalid 'executor' parameter for Promise",
            hint => "Expected an Executor object, got: " . (ref($executor) || 'scalar')
        ) unless $executor isa Executor;

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
                # Recursively flatten promises (handles deeply nested promises)
                my $flatten; $flatten = sub ($promise) {
                    $promise->then(
                        sub ($inner) {
                            if ($inner isa Promise) {
                                $flatten->($inner);  # Continue flattening
                            } else {
                                $p->resolve($inner);  # Base case
                            }
                            ()
                        },
                        sub { $p->reject(@_); () }
                    );
                };
                $flatten->($result);
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
        Error->throw(
            message => "Cannot resolve promise",
            hint => "Promise is already $status"
        ) unless $status eq IN_PROGRESS;

        $status = RESOLVED;
        $result = $_result;
        $self->_notify;
        $self;
    }

    method reject ($_error) {
        Error->throw(
            message => "Cannot reject promise",
            hint => "Promise is already $status"
        ) unless $status eq IN_PROGRESS;

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

    method timeout ($delay_ticks, $scheduled_executor) {
        Error->throw(
            message => "Invalid executor for timeout",
            hint => "Expected a ScheduledExecutor, got: " . (ref($scheduled_executor) || 'scalar')
        ) unless $scheduled_executor isa ScheduledExecutor;

        my $timeout_promise = $self->new(executor => $scheduled_executor);
        my $timer_id;

        # Schedule timeout timer
        $timer_id = $scheduled_executor->schedule_delayed(
            sub {
                # Only timeout if original promise is still pending
                return unless $self->is_in_progress;
                $timeout_promise->reject("Timeout after ${delay_ticks} ticks");
            },
            $delay_ticks
        );

        # Add handlers directly to avoid creating intermediate promise
        # This is critical for proper promise chaining
        push @resolved => sub ($value) {
            # Original promise resolved - cancel timeout and resolve timeout promise
            # Cancel happens first, before any callbacks run
            $scheduled_executor->cancel_scheduled($timer_id);
            return unless $timeout_promise->is_in_progress;
            $timeout_promise->resolve($value);
        };
        push @rejected => sub ($error) {
            # Original promise rejected - cancel timeout and reject timeout promise
            $scheduled_executor->cancel_scheduled($timer_id);
            return unless $timeout_promise->is_in_progress;
            $timeout_promise->reject($error);
        };

        # If already settled, notify immediately
        $self->_notify unless $self->is_in_progress;

        return $timeout_promise;
    }

    sub delay ($class, $value, $delay_ticks, $scheduled_executor) {
        Error->throw(
            message => "Invalid executor for delay",
            hint => "Expected a ScheduledExecutor, got: " . (ref($scheduled_executor) || 'scalar')
        ) unless $scheduled_executor isa ScheduledExecutor;

        my $promise = $class->new(executor => $scheduled_executor);

        $scheduled_executor->schedule_delayed(
            sub { $promise->resolve($value) },
            $delay_ticks
        );

        return $promise;
    }

}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Promise - Asynchronous promise implementation with executor-based scheduling

=head1 SYNOPSIS

    use grey::static qw[ concurrency::util ];

    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    # Chain promises with then()
    $promise
        ->then(sub ($x) { $x * 2 })
        ->then(sub ($x) { $x + 10 })
        ->then(
            sub ($result) { say "Success: $result" },
            sub ($error)  { say "Error: $error" }
        );

    # Resolve the promise
    $promise->resolve(5);
    $executor->run;  # Output: "Success: 20"

    # Error handling
    my $promise2 = Promise->new(executor => $executor);
    $promise2
        ->then(sub ($x) { die "Error!\n" })
        ->then(
            sub ($x) { say "Won't execute" },
            sub ($e) { say "Caught: $e" }
        );

    $promise2->resolve(1);
    $executor->run;  # Output: "Caught: Error!"

=head1 DESCRIPTION

C<Promise> provides an asynchronous promise implementation inspired by JavaScript
promises. Promises represent eventual completion (or failure) of an asynchronous
operation and its resulting value.

Key features:

=over 4

=item *

B<Three states> - IN_PROGRESS, RESOLVED, or REJECTED

=item *

B<Promise chaining> - Chain multiple async operations with C<then()>

=item *

B<Error propagation> - Errors automatically propagate through the chain

=item *

B<Promise flattening> - Promises returned from C<then()> are automatically flattened

=item *

B<Executor-based scheduling> - All callbacks scheduled via an Executor

=back

=head1 PROMISE STATES

Promises have three possible states, accessible via constants:

=over 4

=item C<Promise-E<gt>IN_PROGRESS>

Initial state - the promise is neither resolved nor rejected.

=item C<Promise-E<gt>RESOLVED>

The promise has been successfully resolved with a value.

=item C<Promise-E<gt>REJECTED>

The promise has been rejected with an error.

=back

State transitions are one-way and permanent:

    IN_PROGRESS -> RESOLVED  (via resolve())
    IN_PROGRESS -> REJECTED  (via reject())

Once a promise is settled (resolved or rejected), it cannot change state.

=head1 CONSTRUCTOR

=head2 new

    my $promise = Promise->new(executor => $executor);

Creates a new promise in the IN_PROGRESS state.

B<Parameters:>

=over 4

=item C<executor> (required)

An C<Executor> instance used to schedule callbacks asynchronously. All promises
in a chain should use the same executor.

=back

B<Dies> if executor is not provided or is not an Executor instance.

=head1 METHODS

=head2 State Accessors

=over 4

=item C<status()>

Returns the current state: C<IN_PROGRESS>, C<RESOLVED>, or C<REJECTED>.

=item C<result()>

Returns the resolved value, or C<undef> if not yet resolved.

=item C<error()>

Returns the rejection error, or C<undef> if not rejected.

=item C<executor()>

Returns the C<Executor> instance for this promise.

=back

=head2 State Predicates

=over 4

=item C<is_in_progress()>

Returns true if the promise is still pending.

=item C<is_resolved()>

Returns true if the promise has been resolved.

=item C<is_rejected()>

Returns true if the promise has been rejected.

=back

=head2 Settlement Methods

=over 4

=item C<resolve($value)>

Resolves the promise with the given value.

B<Parameters:>

=over 4

=item C<$value>

The value to resolve with. Can be any value including C<undef>.

=back

B<Returns:> C<$self> for method chaining.

B<Dies> if the promise is already settled (resolved or rejected).

After resolving, all registered success callbacks (from C<then()>) are scheduled
for execution via the executor.

=item C<reject($error)>

Rejects the promise with the given error.

B<Parameters:>

=over 4

=item C<$error>

The error value or message. Can be any value including C<undef>.

=back

B<Returns:> C<$self> for method chaining.

B<Dies> if the promise is already settled.

After rejecting, all registered error callbacks (from C<then()>) are scheduled
for execution via the executor.

=back

=head2 Chaining

=over 4

=item C<< then($on_fulfilled, $on_rejected) >>

Registers callbacks to handle the promise's eventual value or error.

B<Parameters:>

=over 4

=item C<$on_fulfilled> (required)

Callback invoked when the promise is resolved. Receives the resolved value
as its argument.

    ->then(sub ($value) { ... })

=item C<$on_rejected> (optional)

Callback invoked when the promise is rejected. Receives the error as its
argument. If not provided, rejections propagate to the next promise in the chain.

    ->then(
        sub ($value) { ... },
        sub ($error) { ... }
    )

=back

B<Returns:> A new C<Promise> that will be resolved or rejected based on the
callback's behavior:

=over 4

=item *

If the callback returns a value, the new promise is resolved with that value

=item *

If the callback throws an error (C<die>), the new promise is rejected with that error

=item *

If the callback returns a Promise, the new promise adopts that promise's state (flattening)

=back

B<Promise Chaining Example:>

    $promise
        ->then(sub ($x) { $x * 2 })           # Returns 10
        ->then(sub ($x) { $x + 5 })           # Returns 15
        ->then(sub ($x) { say "Result: $x" }) # Prints "Result: 15"

B<Error Handling Example:>

    $promise
        ->then(sub ($x) { die "Error!" if $x < 0; $x })
        ->then(
            sub ($x) { say "Success: $x" },
            sub ($e) { say "Caught: $e" }
        )

=back

=head1 PROMISE FLATTENING

When a C<then()> callback returns a Promise, it is automatically flattened:

    my $promise1 = Promise->new(executor => $executor);

    $promise1->then(sub ($x) {
        my $promise2 = Promise->new(executor => $executor);
        $executor->next_tick(sub { $promise2->resolve($x * 2) });
        return $promise2;  # Returning a promise
    })->then(sub ($value) {
        say $value;  # Gets the resolved value, not the promise
    });

    $promise1->resolve(5);
    $executor->run;  # Prints "10"

The inner promise's value is extracted and passed to the next C<then()> in the chain.

Promise flattening is recursive, so deeply nested promises (promise → promise →
promise → value) are fully flattened. The final value is always extracted regardless
of nesting depth.

=head1 ERROR PROPAGATION

Errors propagate through the promise chain until caught by an error handler:

    $promise
        ->then(sub { die "Error!" })      # Throws error
        ->then(sub { say "Skip 1" })      # Skipped
        ->then(sub { say "Skip 2" })      # Skipped
        ->then(
            sub { say "Skip 3" },
            sub ($e) { say "Caught: $e" } # Error handled here
        )

If no error handler is provided, the error propagates to the next promise:

    $promise
        ->then(sub { die "Error!" })  # No error handler
        ->then(sub { ... })           # Skipped (no error handler)
        ->then(
            sub { ... },
            sub ($e) { ... }          # Error arrives here
        )

=head1 RECOVERY FROM ERRORS

An error handler can recover by returning a value:

    $promise
        ->then(sub { die "Error!" })
        ->then(
            sub { say "Won't execute" },
            sub ($e) {
                say "Recovering from: $e";
                return 42;  # Recovery value
            }
        )
        ->then(sub ($x) {
            say "Recovered with: $x";  # Prints "Recovered with: 42"
        })

=head1 MULTIPLE HANDLERS

Multiple C<then()> calls can be made on the same promise:

    my $promise = Promise->new(executor => $executor);

    $promise->then(sub ($x) { say "Handler 1: $x" });
    $promise->then(sub ($x) { say "Handler 2: $x" });
    $promise->then(sub ($x) { say "Handler 3: $x" });

    $promise->resolve(42);
    $executor->run;
    # All three handlers execute

=head1 LATE ATTACHMENT

Callbacks can be added after a promise has already settled:

    my $promise = Promise->new(executor => $executor);
    $promise->resolve(42);
    $executor->run;  # Promise is now resolved

    # Add handler after resolution
    $promise->then(sub ($x) { say "Late: $x" });
    $executor->run;  # Prints "Late: 42"

=head1 INTEGRATION WITH EXECUTOR

All promise callbacks are scheduled through the associated C<Executor>:

    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->then(sub ($x) { say $x });
    $promise->resolve(42);

    # Callback is queued in executor but not yet run
    $executor->run;  # Now callback executes: prints "42"

This allows fine-grained control over when async operations execute.

=head1 EXAMPLES

=head2 Basic Promise Chain

    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise
        ->then(sub ($x) { $x + 10 })
        ->then(sub ($x) { $x * 2 })
        ->then(sub ($x) { say "Result: $x" });

    $promise->resolve(5);
    $executor->run;  # Prints "Result: 30"

=head2 Error Handling

    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise
        ->then(sub ($x) {
            die "Negative!" if $x < 0;
            return $x * 2;
        })
        ->then(
            sub ($x) { say "Success: $x" },
            sub ($e) { say "Error: $e" }
        );

    $promise->reject("Something went wrong");
    $executor->run;  # Prints "Error: Something went wrong"

=head2 Promise Flattening

    my $executor = Executor->new;

    my $promise1 = Promise->new(executor => $executor);
    $promise1->then(sub ($x) {
        # Return another promise
        my $promise2 = Promise->new(executor => $executor);
        $executor->next_tick(sub {
            $promise2->resolve($x * 2);
        });
        return $promise2;
    })->then(sub ($value) {
        say "Final: $value";
    });

    $promise1->resolve(21);
    $executor->run;  # Prints "Final: 42"

=head2 Async Data Processing

    my $executor = Executor->new;

    sub fetch_user_async ($id) {
        my $promise = Promise->new(executor => $executor);
        $executor->next_tick(sub {
            # Simulate async database fetch
            $promise->resolve({ id => $id, name => "User $id" });
        });
        return $promise;
    }

    sub process_user ($user) {
        my $promise = Promise->new(executor => $executor);
        $executor->next_tick(sub {
            $user->{processed} = 1;
            $promise->resolve($user);
        });
        return $promise;
    }

    fetch_user_async(42)
        ->then(sub ($user) {
            say "Fetched: $user->{name}";
            return process_user($user);
        })
        ->then(sub ($user) {
            say "Processed: $user->{name}";
        });

    $executor->run;

=head2 Time Operations

=over 4

=item C<< timeout($delay_ticks, $scheduled_executor) >>

Adds a timeout to a promise. Returns a new promise that will be rejected with a
timeout error if the original promise doesn't settle within the specified delay.

B<Parameters:>

=over 4

=item C<$delay_ticks>

Number of ticks to wait before timing out.

=item C<$scheduled_executor>

A C<ScheduledExecutor> instance that provides time-based scheduling.

=back

B<Returns:> A new C<Promise> that:

=over 4

=item *

Resolves with the original promise's value if it settles before the timeout

=item *

Rejects with a timeout error if the delay elapses first

=back

The timeout timer is automatically cancelled if the promise settles before the timeout.

B<Example:>

    my $executor = ScheduledExecutor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->timeout(100, $executor)
        ->then(
            sub ($value) { say "Success: $value" },
            sub ($error) { say "Error: $error" }
        );

    # Resolve before timeout
    $executor->schedule_delayed(sub { $promise->resolve("Done!") }, 50);
    $executor->run;  # Prints "Success: Done!"

=item C<< delay($class, $value, $delay_ticks, $scheduled_executor) >>

Factory method that creates a promise which resolves with the given value after
a specified delay.

B<Parameters:>

=over 4

=item C<$value>

The value to resolve with after the delay.

=item C<$delay_ticks>

Number of ticks to wait before resolving.

=item C<$scheduled_executor>

A C<ScheduledExecutor> instance that provides time-based scheduling.

=back

B<Returns:> A new C<Promise> that will resolve with C<$value> after C<$delay_ticks>.

B<Example:>

    my $executor = ScheduledExecutor->new;

    Promise->delay("Hello", 10, $executor)
        ->then(sub ($msg) { say $msg });

    $executor->run;  # Waits 10 ticks, then prints "Hello"

    # Chaining delayed promises
    Promise->delay(5, 10, $executor)
        ->then(sub ($x) { $x * 2 })
        ->then(sub ($x) { say $x });

    $executor->run;  # Prints "10" after 10 ticks

=back

=head1 LIMITATIONS

=over 4

=item *

Promise cancellation is not currently supported (except for timeout timers which
are automatically cancelled).

=back

=head1 SEE ALSO

=over 4

=item *

L<Executor> - Event loop executor for callback scheduling

=item *

L<grey::static::concurrency> - Concurrency features including reactive flows

=item *

JavaScript Promises - L<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise>

=back

=head1 AUTHOR

grey::static

=cut
