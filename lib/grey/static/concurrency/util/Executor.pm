
use v5.42;
use experimental qw[ class try ];

class Executor {
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

        while (blessed $t && $t isa Executor) {
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

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Executor - Event loop executor for callback scheduling

=head1 SYNOPSIS

    use grey::static qw[ concurrency::util ];

    my $executor = Executor->new;

    # Queue callbacks
    $executor->next_tick(sub { say "First" });
    $executor->next_tick(sub { say "Second" });
    $executor->next_tick(sub { say "Third" });

    # Run the event loop
    $executor->run;
    # Output:
    # First
    # Second
    # Third

    # Executor chaining
    my $ex1 = Executor->new;
    my $ex2 = Executor->new;
    $ex1->set_next($ex2);

    $ex1->next_tick(sub { say "From ex1" });
    $ex2->next_tick(sub { say "From ex2" });

    $ex1->run;  # Runs both executors in order

=head1 DESCRIPTION

C<Executor> is a simple event loop that queues and executes callbacks. It provides
the foundation for asynchronous programming in grey::static, used by Promises,
Flows, and other concurrency features.

Key features:

=over 4

=item *

B<Callback queuing> - Schedule callbacks with C<next_tick()>

=item *

B<Batch execution> - All queued callbacks run in one C<tick()>

=item *

B<Executor chaining> - Link multiple executors together

=item *

B<Cycle detection> - Prevents circular executor chains

=item *

B<Exception handling> - Preserves remaining callbacks on errors

=back

=head1 EXECUTION MODEL

Executor uses a simple FIFO queue:

=over 4

=item 1.

Callbacks are added to the queue via C<next_tick()>

=item 2.

C<tick()> drains the entire queue in one batch

=item 3.

New callbacks added during execution are queued for the next tick

=item 4.

C<run()> continues calling C<tick()> until all executors in the chain are done

=back

Example execution:

    $executor->next_tick(sub {
        say "A";
        $executor->next_tick(sub { say "C" });  # Queued for next tick
    });
    $executor->next_tick(sub { say "B" });

    $executor->run();
    # Output:
    # A
    # B
    # C

=head1 CONSTRUCTOR

=head2 new

    my $executor = Executor->new;
    my $executor = Executor->new(next => $other_executor);

Creates a new Executor with an empty callback queue.

B<Parameters:>

=over 4

=item C<next> (optional)

Another Executor to chain to. When this executor finishes a tick with no remaining
callbacks, execution continues to the next executor.

B<Dies> if setting C<next> would create a circular chain.

=back

=head1 METHODS

=head2 Scheduling

=over 4

=item C<next_tick($callback)>

Queues a callback for execution on the next tick.

B<Parameters:>

=over 4

=item C<$callback>

Code reference to execute. Receives no arguments.

=back

Callbacks are executed in FIFO order (first queued, first executed).

B<Example:>

    $executor->next_tick(sub { say "Hello" });
    $executor->next_tick(sub { say "World" });
    $executor->tick();  # Prints "Hello" then "World"

=back

=head2 Execution

=over 4

=item C<tick()>

Executes all currently queued callbacks in one batch.

B<Returns:> The next executor in the chain, or C<undef> if no next executor.

Callbacks queued during C<tick()> are NOT executed in the same batch - they
wait for the next C<tick()> call.

If a callback throws an exception:
- Remaining callbacks are preserved in the queue
- Exception is re-thrown
- Call C<tick()> again to continue execution

B<Example:>

    $executor->next_tick(sub { say "1" });
    $executor->next_tick(sub { say "2" });
    $executor->next_tick(sub { say "3" });

    $executor->tick();  # Prints: 1, 2, 3
    $executor->tick();  # No output (queue empty)

=item C<run()>

Runs the event loop until all executors in the chain are done.

Continues calling C<tick()> on this executor and any chained executors until
all callback queues are empty.

B<Example:>

    $executor->next_tick(sub {
        say "Tick 1";
        $executor->next_tick(sub { say "Tick 2" });
    });

    $executor->run();  # Runs until all callbacks complete

=back

=head2 Executor Chaining

=over 4

=item C<set_next($executor)>

Sets the next executor in the chain.

B<Parameters:>

=over 4

=item C<$executor>

Another Executor to chain to, or C<undef> to remove chaining.

=back

B<Dies> if setting this would create a circular chain (e.g., A → B → A).

After an executor completes a tick with no remaining callbacks, execution
automatically continues to the next executor.

B<Example:>

    my $ex1 = Executor->new;
    my $ex2 = Executor->new;
    $ex1->set_next($ex2);

    $ex1->next_tick(sub { say "From ex1" });
    $ex2->next_tick(sub { say "From ex2" });

    $ex1->run();
    # Prints:
    # From ex1
    # From ex2

=item C<next()>

Returns the next executor in the chain, or C<undef>.

This is a read-only accessor. Use C<set_next()> to modify the chain.

=item C<find_next_undone()>

Finds the next executor in the chain that has queued callbacks.

B<Returns:> The first executor with remaining callbacks, or C<undef> if all are done.

Traverses the chain starting from this executor.

=item C<collect_all()>

Returns a list of all executors in the chain, starting from this one.

B<Example:>

    my @all = $executor->collect_all();
    say "Chain has " . scalar(@all) . " executors";

=back

=head2 Status

=over 4

=item C<is_done()>

Returns true if no callbacks are queued.

B<Example:>

    $executor->next_tick(sub { say "Hi" });
    say $executor->is_done;  # 0 (false)
    $executor->tick();
    say $executor->is_done;  # 1 (true)

=item C<remaining()>

Returns the number of queued callbacks.

B<Example:>

    $executor->next_tick(sub { });
    $executor->next_tick(sub { });
    say $executor->remaining;  # 2

=back

=head2 Debugging

=over 4

=item C<to_string()>

Returns a string representation of the executor (includes memory address).

B<Example:>

    say $executor->to_string;  # "Executor[123456789]"

=item C<diag()>

Diagnostic method for debugging executor state.

Currently a placeholder for future diagnostic functionality.

=item C<shutdown()>

Placeholder for cleanup/shutdown operations.

Currently calls C<diag()>.

=back

=head1 USAGE PATTERNS

=head2 Simple Event Loop

    my $executor = Executor->new;

    $executor->next_tick(sub { say "Task 1" });
    $executor->next_tick(sub { say "Task 2" });
    $executor->next_tick(sub { say "Task 3" });

    $executor->run();

=head2 Recursive Scheduling

    my $executor = Executor->new;
    my $count = 0;

    my $task; $task = sub {
        say "Count: $count";
        $count++;
        $executor->next_tick($task) if $count < 5;
    };

    $executor->next_tick($task);
    $executor->run();
    # Prints: Count: 0, 1, 2, 3, 4

=head2 Executor Chain for Separation

    my $high_priority = Executor->new;
    my $low_priority = Executor->new;
    $high_priority->set_next($low_priority);

    # High priority tasks
    $high_priority->next_tick(sub { say "Urgent task" });

    # Low priority tasks
    $low_priority->next_tick(sub { say "Background task" });

    # High priority runs first, then low priority
    $high_priority->run();

=head2 Exception Handling

    my $executor = Executor->new;

    $executor->next_tick(sub { say "Before error" });
    $executor->next_tick(sub { die "Oops\n" });
    $executor->next_tick(sub { say "After error (preserved)" });

    try {
        $executor->run();
    } catch ($e) {
        say "Caught: $e";
        # Remaining callback still queued
        say "Remaining: " . $executor->remaining;  # 1
        $executor->run();  # Continue execution
    }

=head1 INTEGRATION WITH OTHER FEATURES

=head2 With Promises

Executor is the foundation for Promise scheduling:

    my $executor = Executor->new;
    my $promise = Promise->new(executor => $executor);

    $promise->then(sub ($x) { say $x });
    $promise->resolve(42);

    $executor->run();  # Promise callbacks execute

=head2 With Flow

Executor manages Flow operation callbacks:

    my $executor = Executor->new;
    my $publisher = Flow::Publisher->of([1, 2, 3], $executor);

    $publisher->subscribe(
        on_next => sub ($x) { say $x },
        on_complete => sub { say "Done" }
    );

    $executor->run();

=head2 With ScheduledExecutor

ScheduledExecutor extends Executor to add time-based scheduling:

    my $scheduled = ScheduledExecutor->new;
    $scheduled->next_tick(sub { say "Immediate" });
    $scheduled->schedule_delayed(sub { say "Delayed" }, 10);
    $scheduled->run();

=head1 CYCLE DETECTION

Executor prevents circular chains to avoid infinite loops:

    my $ex1 = Executor->new;
    my $ex2 = Executor->new;

    $ex1->set_next($ex2);
    $ex2->set_next($ex1);  # Dies: "Circular executor chain detected"

The cycle detector traverses the chain when C<set_next()> is called,
ensuring no executor appears twice.

=head1 PERFORMANCE CHARACTERISTICS

=over 4

=item *

B<next_tick()>: O(1) - append to array

=item *

B<tick()>: O(n) where n = number of callbacks

=item *

B<set_next()>: O(n) where n = chain length (cycle detection)

=item *

B<find_next_undone()>: O(n) where n = chain length

=item *

B<Memory>: O(n) where n = number of queued callbacks

=back

=head1 NOTES

=over 4

=item *

Callbacks queued during C<tick()> execute on the B<next> tick, not the current one

=item *

Exceptions preserve remaining callbacks but stop the current tick

=item *

Executor chains execute sequentially (not concurrently)

=item *

C<run()> continues until all executors in the chain are done

=back

=head1 SEE ALSO

=over 4

=item *

L<ScheduledExecutor> - Executor with time-based scheduling

=item *

L<Promise> - Async promise implementation using Executor

=item *

L<Flow::Publisher> - Reactive publisher using Executor

=item *

L<grey::static::concurrency::util> - Feature loader for concurrency utilities

=back

=head1 AUTHOR

grey::static

=cut
