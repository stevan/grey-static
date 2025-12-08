use v5.42;
use experimental qw(builtin);
use builtin qw(load_module);

package grey::static::concurrency;

our $VERSION = '0.01';

use File::Basename ();
use lib File::Basename::dirname(__FILE__) . '/concurrency';

load_module('Flow');

sub import { }

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

grey::static::concurrency - Reactive flow-based concurrency primitives

=head1 SYNOPSIS

    use grey::static qw[ functional concurrency ];

    # Create a publisher and build a flow
    my $publisher = Flow::Publisher->new;

    Flow->from($publisher)
        ->map(sub ($x) { $x * 2 })
        ->grep(sub ($x) { $x > 10 })
        ->to(sub ($x) { say "Result: $x" }, request_size => 5)
        ->build;

    # Submit values
    $publisher->submit(3);
    $publisher->submit(5);
    $publisher->submit(10);

    # Start processing and close
    $publisher->start;
    $publisher->close;

=head1 DESCRIPTION

The C<concurrency> feature provides reactive, flow-based concurrency primitives
based on the Reactive Streams specification. It implements a publisher-subscriber
pattern with backpressure support through demand-based flow control.

The main class is C<Flow>, which provides a fluent API for building reactive
pipelines. Operations are executed asynchronously using an event loop executor.

=head1 CLASSES

=head2 Flow

Fluent builder for creating reactive data pipelines.

=head3 Class Methods

=over 4

=item C<< from($publisher) >>

Creates a new C<Flow> from a C<Flow::Publisher>.

B<Parameters:>

=over 4

=item C<$publisher>

A C<Flow::Publisher> instance to use as the data source.

=back

B<Returns:> A new C<Flow> instance.

=back

=head3 Methods

=over 4

=item C<source()>

Returns the C<Flow::Publisher> source for this flow.

=item C<sink()>

Returns the C<Flow::Subscriber> sink for this flow, if set via C<to()>.

=item C<ops()>

Returns an array of C<Flow::Operation> objects in this flow.

=item C<< map($f) >>

Adds a map operation to transform each element.

B<Parameters:>

=over 4

=item C<$f>

Either a code reference or a C<Function> object. Transforms each element
to a new value.

=back

B<Returns:> C<$self> for method chaining.

=item C<< grep($f) >>

Adds a filter operation to select elements.

B<Parameters:>

=over 4

=item C<$f>

Either a code reference or a C<Predicate> object. Returns true to keep
the element, false to filter it out.

=back

B<Returns:> C<$self> for method chaining.

=item C<< to($subscriber, %args) >>

Sets the sink (subscriber) for this flow.

B<Parameters:>

=over 4

=item C<$subscriber>

Can be:

=over 4

=item *

A C<Flow::Subscriber> instance

=item *

A C<Consumer> instance (wrapped in a C<Flow::Subscriber>)

=item *

A code reference (wrapped in a C<Consumer>, then C<Flow::Subscriber>)

=back

=item C<%args>

Optional arguments passed to C<Flow::Subscriber> constructor if creating one.
Common argument: C<request_size> (defaults to 1).

=back

B<Returns:> C<$self> for method chaining.

=item C<build()>

Builds the flow by connecting all operations and the subscriber.

B<Returns:> The source C<Flow::Publisher>, allowing you to submit values
and control execution.

=back

=head2 Flow::Publisher

Publishes values to subscribers with backpressure support.

=head3 Constructor

    my $publisher = Flow::Publisher->new;

=head3 Methods

=over 4

=item C<executor()>

Returns the C<Flow::Executor> managing async execution for this publisher.

=item C<subscription()>

Returns the current C<Flow::Subscription>, or C<undef> if no subscriber.

=item C<< subscribe($subscriber) >>

Subscribes a C<Flow::Subscriber> to this publisher.

Creates a subscription and schedules C<on_subscribe> callback.

=item C<< submit($value) >>

Submits a value to the flow. The value is buffered and sent when the
subscriber requests it.

=item C<start()>

Starts the executor's event loop to begin processing.

=item C<< close($callback) >>

Closes the publisher after draining all buffered values.

B<Parameters:>

=over 4

=item C<$callback>

Optional code reference called after completion.

=back

Completes the subscription, runs the executor, and shuts it down.

=back

=head2 Flow::Subscriber

Consumes values from a publisher with demand-based backpressure.

=head3 Constructor

    my $subscriber = Flow::Subscriber->new(
        consumer     => $consumer,      # Consumer or code ref (required)
        request_size => 10,             # Request batch size (default: 1)
    );

=head3 Methods

=over 4

=item C<consumer()>

Returns the C<Consumer> that processes each element.

=item C<request_size()>

Returns the number of elements requested per batch.

=item C<< on_subscribe($subscription) >>

Called when subscribed to a publisher. Stores the subscription and requests
the initial batch of elements.

=item C<on_unsubscribe()>

Called when unsubscribed. Clears the subscription reference.

=item C<< on_next($element) >>

Called for each element. Decrements the demand counter and requests more
elements when needed. Passes the element to the consumer.

=item C<on_completed()>

Called when the publisher completes. Cancels the subscription.

=item C<< on_error($error) >>

Called when an error occurs. Cancels the subscription.

=back

=head2 Flow::Subscription

Manages the connection between a publisher and subscriber, coordinating
demand and delivery.

=head3 Constructor

Created automatically by C<Flow::Publisher->subscribe()>. Not typically
constructed directly.

=head3 Methods

=over 4

=item C<publisher()>

Returns the C<Flow::Publisher> for this subscription.

=item C<subscriber()>

Returns the C<Flow::Subscriber> for this subscription.

=item C<executor()>

Returns the C<Flow::Executor> managing async execution.

=item C<< request($n) >>

Requests C<$n> more elements from the publisher. Increments demand and
drains buffered elements if available.

=item C<cancel()>

Cancels the subscription, stopping element delivery.

=item C<< offer($element) >>

Called by the publisher to offer an element. Buffers the element and
delivers it if demand exists.

=item C<on_unsubscribe()>

Forwards the unsubscribe notification to the subscriber.

=item C<< on_next($element) >>

Forwards an element to the subscriber.

=item C<on_completed()>

Forwards the completion notification to the subscriber.

=item C<< on_error($error) >>

Forwards an error to the subscriber.

=back

=head2 Flow::Executor

Event loop executor for async task scheduling. Automatically created by
C<Flow::Publisher>.

See the Flow::Executor class for detailed API documentation.

=head2 Flow::Operation

Base class for flow operations. Subclasses include:

=over 4

=item C<Flow::Operation::Map>

Transforms elements using a C<Function>.

=item C<Flow::Operation::Grep>

Filters elements using a C<Predicate>.

=back

Operations implement both publisher and subscriber interfaces, acting as
intermediaries in the flow pipeline.

=head1 BACKPRESSURE

The flow system implements backpressure through demand-based flow control:

=over 4

=item 1.

Subscriber requests N elements via C<request($n)>

=item 2.

Publisher sends at most N elements

=item 3.

Subscriber processes elements and requests more

=item 4.

Buffering occurs when supply exceeds demand

=back

This prevents overwhelming subscribers with data they can't process.

=head1 DEPENDENCIES

Requires the C<functional> feature for C<Function>, C<Predicate>, and
C<Consumer> classes.

=head1 SEE ALSO

L<grey::static>, L<grey::static::functional>

Reactive Streams Specification: L<https://www.reactive-streams.org/>

=head1 AUTHOR

grey::static

=cut
