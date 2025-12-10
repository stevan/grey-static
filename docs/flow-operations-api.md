# Flow Operations API Design

## Overview

Flow operations provide reactive stream transformations with backpressure support. Flow is a **push-based** reactive API where publishers push elements to subscribers, unlike Stream which is **pull-based**.

Key differences:
- **Stream**: Pull-based, lazy evaluation, subscriber pulls elements on demand
- **Flow**: Push-based, reactive, publisher pushes elements to subscriber with backpressure

Flow operations wrap and transform Flow::Publishers, handling subscription, backpressure, and cancellation automatically.

## Coding Standards (IMPORTANT)

**Perl 5.42+ Modern Practices:**

1. ALWAYS use signatures in subs - NEVER use @_
   ```perl
   # GOOD
   sub map ($class, $source, $function) { ... }

   # BAD
   sub map { my ($class, $source, $function) = @_; ... }
   ```

2. DO NOT include trailing `1;` in modules - not needed in 5.42
   ```perl
   # GOOD
   class Flow::Publisher::Map { ... }
   # End of file - no 1;

   # BAD
   class Flow::Publisher::Map { ... }
   1;
   ```

3. USE builtin functions where applicable
   ```perl
   use builtin qw[ true false blessed reftype ];
   ```

4. PREFER method chaining for flow operations
   ```perl
   # GOOD
   $publisher
       ->map($transform)
       ->filter($predicate)
       ->subscribe($subscriber);

   # BAD (but sometimes necessary)
   my $mapped = $publisher->map($transform);
   my $filtered = $mapped->filter($predicate);
   $filtered->subscribe($subscriber);
   ```

## Design Principles

- All operations return new Flow::Publisher instances (immutable chain)
- Respect backpressure throughout the chain
- Handle cancellation properly (propagate upstream)
- Use `field $source :param` for the upstream publisher
- Operations are lazy - nothing happens until subscribe()
- Errors propagate downstream via onError()
- Completion propagates downstream via onComplete()
- Single-word method names preferred (map, filter, take vs mapValues, filterBy, takeN)
- All publishers implement Flow::Publisher interface
- Type consistency: use Function, Predicate, Consumer, BiFunction from functional API

## Operation Categories

### 1. Transformation Operations

Transform elements flowing through the publisher.

#### map($function)

Transform each element with a function.

```perl
$publisher->map(Function->new(f => sub ($x) { $x * 2 }))
    ->subscribe($subscriber);
```

Implementation:
- Create Flow::Publisher::Map wrapper
- On element: apply function, push result downstream
- Propagate errors and completion
- Respect backpressure from downstream

#### flatMap($function)

Transform each element into a Publisher and flatten the results.

```perl
$publisher->flatMap(Function->new(f => sub ($id) {
    return fetch_user($id);  # Returns Publisher
}))
```

Implementation:
- Most complex operation - manage multiple subscriptions
- Subscribe to inner publishers as outer elements arrive
- Merge/concat/switch strategies for handling multiple active subscriptions
- Careful backpressure management across nested subscriptions

#### scan($initial, $bifunction)

Running accumulator (like reduce but emits intermediate results).

```perl
# Running sum: emits 1, 3, 6, 10, 15 for input 1,2,3,4,5
$publisher->scan(0, BiFunction->new(f => sub ($acc, $x) { $acc + $x }))
```

Implementation:
- Maintain accumulator state
- On element: compute new accumulator, emit it
- Initial value emitted first (optional design choice)

### 2. Filtering Operations

Select which elements flow through.

#### filter($predicate)

Only emit elements matching predicate.

```perl
$publisher->filter(Predicate->new(p => sub ($x) { $x % 2 == 0 }))
```

Implementation:
- On element: test predicate, only push downstream if true
- Backpressure tricky: must request more from upstream when filtering

#### take($n)

Emit only first N elements, then complete.

```perl
$publisher->take(10)
```

Implementation:
- Count elements
- After N elements, call onComplete() and cancel upstream

#### takeWhile($predicate)

Emit while predicate is true, complete on first false.

```perl
$publisher->takeWhile(Predicate->new(p => sub ($x) { $x < 100 }))
```

#### takeUntil($signal)

Emit until signal publisher emits (useful for timeouts, cancellation).

```perl
$publisher->takeUntil($stop_signal)
```

#### skip($n)

Skip first N elements.

```perl
$publisher->skip(5)
```

#### skipWhile($predicate)

Skip while predicate is true.

```perl
$publisher->skipWhile(Predicate->new(p => sub ($x) { $x < 10 }))
```

### 3. Combining Operations

Combine multiple publishers.

#### Flow::Publishers->merge(@publishers)

Merge multiple publishers - emit from any as soon as available.

```perl
Flow::Publishers->merge($pub1, $pub2, $pub3)
```

Implementation:
- Subscribe to all publishers
- Forward all elements downstream
- Complete when all complete
- Error if any errors

#### Flow::Publishers->concat(@publishers)

Concatenate publishers - emit $pub1 fully, then $pub2, etc.

```perl
Flow::Publishers->concat($pub1, $pub2, $pub3)
```

Implementation:
- Subscribe to first publisher
- On complete, subscribe to next
- Chain until all complete

#### Flow::Publishers->zip(@publishers, $combiner)

Pair up corresponding elements from multiple publishers.

```perl
Flow::Publishers->zip($pubA, $pubB, BiFunction->new(f => sub ($a, $b) {
    return [$a, $b];
}))
```

Implementation:
- Subscribe to all publishers
- Buffer elements from each
- When all have element, combine and emit
- Complete when any completes

#### Flow::Publishers->combineLatest(@publishers, $combiner)

Emit whenever any publisher emits, using latest from others.

```perl
Flow::Publishers->combineLatest($pubA, $pubB, BiFunction->new(f => sub ($a, $b) {
    return $a + $b;
}))
```

Implementation:
- Subscribe to all publishers
- Track latest value from each
- When any emits, combine all latest and emit result
- Only start emitting after all have emitted at least once

### 4. Timing Operations

Control timing of emissions.

#### delay($ms, $executor)

Delay entire sequence by N milliseconds.

```perl
$publisher->delay(1000, $executor)
```

Implementation:
- Buffer all elements
- Schedule first element for t + delay
- Subsequent elements maintain relative timing

#### delayEach($ms, $executor)

Add delay between each element.

```perl
$publisher->delayEach(100, $executor)
```

Implementation:
- On element received: schedule emission for current_time + delay
- Queue elements if they arrive faster than delay

#### throttle($min_delay, $executor)

Rate limiting - enforce minimum delay between emissions.

```perl
$publisher->throttle(100, $executor)  # Max 10/second
```

Implementation:
- Track last emission time
- Drop/buffer elements arriving too fast
- Similar to Stream::Operation::Throttle but push-based

#### debounce($quiet_delay, $executor)

Emit only after quiet period (no emissions for N ms).

```perl
$publisher->debounce(300, $executor)
```

Implementation:
- On element: cancel previous timer, schedule new one
- If timer fires, emit buffered element
- Useful for search-as-you-type

#### sample($interval, $executor)

Sample at regular intervals.

```perl
$publisher->sample(1000, $executor)  # Sample every second
```

Implementation:
- Track latest element
- Schedule periodic timer
- On timer: emit latest element if any

#### timeout($duration, $executor)

Error if no element received within duration.

```perl
$publisher->timeout(5000, $executor)
```

Implementation:
- Schedule timeout on subscribe
- Reset timeout on each element
- If timeout fires, call onError()

#### buffer($size)

Collect elements into batches of N.

```perl
$publisher->buffer(100)
    ->subscribe(Subscriber->new(
        onNext => sub ($batch) { process_batch($batch) }
    ));
```

Implementation:
- Accumulate elements in array
- When size reached, emit batch and clear
- On complete, emit partial batch if any

#### bufferTime($duration, $executor)

Collect elements into time windows.

```perl
$publisher->bufferTime(1000, $executor)  # 1 second windows
```

Implementation:
- Schedule periodic timer
- Accumulate elements
- On timer: emit batch and start new window

### 5. Error Handling Operations

Handle errors in the stream.

#### retry($count)

Retry failed subscriptions up to N times.

```perl
$publisher->retry(3)
```

Implementation:
- On error: if count remaining, resubscribe to source
- Track attempt count
- After max attempts, propagate error downstream

#### retryWhen($predicate)

Retry based on error and attempt number.

```perl
$publisher->retryWhen(BiFunction->new(f => sub ($error, $attempt) {
    return $attempt < 3 && $error !~ /AuthError/;
}))
```

#### onErrorReturn($value)

On error, emit fallback value and complete.

```perl
$publisher->onErrorReturn("default")
```

Implementation:
- Wrap onError handler
- On error: emit value, call onComplete()

#### onErrorResume($publisher_factory)

On error, switch to backup publisher.

```perl
$publisher->onErrorResume(sub ($error) {
    warn "Failed: $error, using backup";
    return $backup_publisher;
})
```

Implementation:
- On error: call factory, subscribe to result
- Forward elements from backup publisher

### 6. Backpressure Operations

Control flow when subscriber can't keep up.

#### onBackpressureDrop()

Drop elements if subscriber can't keep up.

```perl
$publisher->onBackpressureDrop()
```

Implementation:
- Track downstream request count
- If no outstanding requests, drop element
- Useful for real-time data where latest is most important

#### onBackpressureBuffer($max_size)

Buffer elements up to max size.

```perl
$publisher->onBackpressureBuffer(1000)
```

Implementation:
- Queue elements when downstream is slow
- Error if buffer exceeds max size
- Request from upstream based on buffer space

#### onBackpressureLatest()

Keep only most recent element.

```perl
$publisher->onBackpressureLatest()
```

Implementation:
- Buffer size = 1
- Replace buffered element with latest
- Always have most recent available

### 7. Side Effect Operations

Perform actions without transforming elements.

#### doOnNext($consumer)

Perform action for each element (debugging, logging).

```perl
$publisher->doOnNext(Consumer->new(c => sub ($x) {
    say "Received: $x";
}))
```

Implementation:
- Call consumer before forwarding downstream
- Errors in consumer propagate as stream errors

#### doOnError($consumer)

Perform action when error occurs.

```perl
$publisher->doOnError(Consumer->new(c => sub ($error) {
    warn "Error occurred: $error";
}))
```

#### doOnComplete($runnable)

Perform action when stream completes.

```perl
$publisher->doOnComplete(sub {
    say "Stream completed";
})
```

#### doOnCancel($runnable)

Perform action when subscription cancelled.

```perl
$publisher->doOnCancel(sub {
    say "Subscription cancelled";
})
```

#### doOnSubscribe($consumer)

Perform action when subscribed.

```perl
$publisher->doOnSubscribe(Consumer->new(c => sub ($subscription) {
    say "Subscribed!";
}))
```

### 8. Terminal Operations

Operations that trigger subscription and return a result.

#### forEach($consumer)

Subscribe and consume all elements.

```perl
$publisher->forEach(Consumer->new(c => sub ($x) {
    say $x;
}))
```

Returns: Subscription (can be cancelled)

#### collect($collector)

Collect all elements into a data structure.

```perl
my $list = $publisher->collect(Flow::Collectors->ToList());
my $sum = $publisher->collect(Flow::Collectors->Sum());
```

Returns: Promise that resolves with collected result

#### reduce($initial, $bifunction)

Reduce to single value.

```perl
my $sum_promise = $publisher->reduce(0, BiFunction->new(f => sub ($a, $b) {
    return $a + $b;
}));
```

Returns: Promise with final result

#### toList()

Convenience for collect(ToList).

```perl
my $list_promise = $publisher->toList();
```

Returns: Promise<List>

## Implementation Architecture

### Core Classes

```
Flow::Publisher (interface)
├── Flow::Publisher::Map
├── Flow::Publisher::Filter
├── Flow::Publisher::FlatMap
├── Flow::Publisher::Take
├── Flow::Publisher::Skip
├── Flow::Publisher::Merge
├── Flow::Publisher::Concat
├── Flow::Publisher::Zip
├── Flow::Publisher::Buffer
├── Flow::Publisher::Throttle
├── Flow::Publisher::Debounce
├── Flow::Publisher::Timeout
├── Flow::Publisher::Retry
└── Flow::Publisher::DoOn (side effects)
```

### Publisher Pattern

Each operation follows this pattern:

```perl
class Flow::Publisher::Map :isa(Flow::Publisher) {
    field $source :param;      # Upstream publisher
    field $function :param;    # Transformation function

    method subscribe ($subscriber) {
        # Create wrapper subscriber that:
        # 1. Transforms elements with $function
        # 2. Forwards to $subscriber
        # 3. Handles backpressure
        # 4. Propagates errors/completion

        my $wrapper = Flow::Subscriber->new(
            onNext => sub ($item) {
                my $result = eval { $function->apply($item) };
                if ($@) {
                    $subscriber->onError($@);
                } else {
                    $subscriber->onNext($result);
                }
            },
            onError => sub ($error) {
                $subscriber->onError($error);
            },
            onComplete => sub {
                $subscriber->onComplete();
            },
            onSubscribe => sub ($subscription) {
                $subscriber->onSubscribe($subscription);
            }
        );

        $source->subscribe($wrapper);
    }
}
```

### Backpressure Handling

Flow uses the request(n) model:

1. Subscriber calls `$subscription->request($n)` to request N elements
2. Publisher emits up to N elements via `onNext()`
3. Subscriber requests more when ready
4. Each operation in chain manages its own request/emit balance

Example with buffering:

```perl
class Flow::Publisher::Buffer {
    field @buffer;
    field $requested = 0;

    # When downstream requests
    method onRequest ($n) {
        $requested += $n;
        $self->flush_buffer();

        # Request more from upstream if buffer low
        if (@buffer < $batch_size) {
            $upstream_subscription->request($batch_size);
        }
    }

    # When upstream emits
    method onNext ($item) {
        push @buffer, $item;

        if (@buffer >= $batch_size) {
            my $batch = [splice @buffer, 0, $batch_size];
            $self->emit_batch($batch);
        }
    }
}
```

## Integration with Existing APIs

### Stream Integration

Flow and Stream serve different purposes:

**When to use Stream:**
- Pull-based processing
- Working with finite collections
- Lazy evaluation needed
- Simple transformations

**When to use Flow:**
- Push-based/reactive processing
- Asynchronous data sources
- Backpressure required
- Event streams, real-time data

Converting between them:

```perl
# Stream to Flow
my $publisher = Flow::Publishers->fromStream($stream);

# Flow to Stream (blocking - collects all)
my $stream = $publisher->toStream();
```

### Promise Integration

Terminal Flow operations return Promises:

```perl
my $result_promise = $publisher
    ->map($transform)
    ->filter($predicate)
    ->reduce(0, $accumulator);

$result_promise->then(sub ($result) {
    say "Final result: $result";
});
```

### Executor Integration

Time-based operations require ScheduledExecutor:

```perl
my $executor = ScheduledExecutor->new;

$publisher
    ->throttle(100, $executor)
    ->debounce(300, $executor)
    ->timeout(5000, $executor)
    ->subscribe($subscriber);

$executor->run();
```

## Priority Implementation Order

### Phase 1: Core Transformations (Essential)
1. **map** - Most basic transformation
2. **filter** - Essential filtering
3. **take** - Limiting output
4. **skip** - Skipping elements

### Phase 2: Side Effects & Debugging
5. **doOnNext** - Debugging and logging
6. **doOnError** - Error logging
7. **doOnComplete** - Completion handling

### Phase 3: Combining Publishers
8. **merge** - Most useful combiner
9. **concat** - Sequential composition
10. **zip** - Pairing elements

### Phase 4: Error Handling
11. **retry** - Basic retry logic
12. **onErrorReturn** - Fallback values
13. **onErrorResume** - Fallback publishers

### Phase 5: Advanced Transformations
14. **flatMap** - Most powerful (and complex)
15. **scan** - Running aggregations

### Phase 6: Timing & Backpressure
16. **buffer** / **bufferTime** - Batching
17. **throttle** - Rate limiting
18. **debounce** - Quiet period
19. **timeout** - Failure detection
20. **onBackpressureDrop/Buffer** - Backpressure strategies

### Phase 7: Terminal Operations
21. **forEach** - Simple consumption
22. **collect** - Accumulation
23. **reduce** - Single value
24. **toList** - Convenience

## Design Decisions

1. **Push-based reactive model** - Publisher pushes to subscriber (vs Stream's pull-based)

2. **Backpressure via request(n)** - Subscriber controls flow by requesting elements

3. **Lazy execution** - Nothing happens until subscribe() called

4. **Errors stop the stream** - onError() terminates stream (no recovery without explicit error handling)

5. **Single subscription** - Some publishers may only allow one subscriber (cold vs hot publishers)

6. **Cancellation propagates upstream** - Calling subscription.cancel() stops entire chain

7. **Operations are immutable** - Each operation returns new Publisher (chains don't modify original)

8. **Type compatibility with Stream** - Use same Function/Predicate/Consumer types

9. **Time operations require ScheduledExecutor** - Explicit executor dependency for testability

10. **Terminal operations return Promises** - Async result handling with executor integration

## Testing Strategy

Each operation needs:

1. **Basic functionality tests**
   ```perl
   my @results;
   $publisher->map($f)->subscribe(sub ($x) { push @results, $x });
   is_deeply(\@results, [expected]);
   ```

2. **Backpressure tests**
   ```perl
   # Request 1 at a time
   $subscription->request(1);
   is(scalar(@received), 1, 'respects backpressure');
   ```

3. **Error propagation tests**
   ```perl
   my $error;
   $publisher->subscribe(
       onNext => sub {},
       onError => sub ($e) { $error = $e }
   );
   like($error, qr/expected error/);
   ```

4. **Cancellation tests**
   ```perl
   $subscription->cancel();
   ok($upstream_cancelled, 'cancellation propagates');
   ```

5. **Timing tests** (for time-based operations)
   ```perl
   my $executor = ScheduledExecutor->new;
   my $start = $executor->current_time;
   # ... operation ...
   $executor->run;
   my $elapsed = $executor->current_time - $start;
   cmp_ok($elapsed, '>=', $expected_ms);
   ```

## Open Questions

1. **Hot vs Cold publishers** - Should we distinguish? Default behavior?
   - Cold: New data for each subscriber (most operations)
   - Hot: Shared data across subscribers (useful for events)

2. **Multicasting** - Should publishers support multiple subscribers by default?

3. **ConnectablePublisher** - Publish/connect pattern for manual control?

4. **Schedulers** - Should operations have default schedulers or always require explicit executor?

5. **Buffer overflow** - Drop oldest vs newest vs error? Configurable?

6. **FlatMap strategies** - Merge (concurrent) vs concat (sequential) vs switch (cancel previous)?

7. **Resource cleanup** - How to handle resources (file handles, connections) in stream lifecycle?

8. **Peek vs doOnNext** - Do we need both or just doOnNext?

9. **Materialization** - Should we expose stream lifecycle as elements (start, complete, error)?

10. **Performance** - Should we optimize for common chains (map->filter fusion)?
