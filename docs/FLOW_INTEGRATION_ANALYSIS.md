# Flow + ScheduledExecutor Integration Analysis
## Deep Dive - 2025-12-09

## Executive Summary

This document analyzes the integration possibilities between the Flow reactive API and ScheduledExecutor, examining the architecture of both systems, identifying design inconsistencies, and proposing integration strategies.

**Key Finding:** Flow and ScheduledExecutor come from different architectural paradigms and may not need tight integration. They serve different purposes and can coexist as complementary tools.

---

## Part 1: Flow Architecture Analysis

### Core Components

#### 1. Flow::Publisher
**Purpose:** Source of data in reactive stream
**Key Features:**
- Creates own Executor in ADJUST block (Publisher.pm:16)
- Manages subscription lifecycle
- Buffers values until subscriber ready
- Schedules all operations via `executor->next_tick()`

```perl
class Flow::Publisher {
    field $executor :reader;
    field $subscription :reader;
    field @buffer;

    ADJUST {
        $executor = Executor->new;  # Each publisher gets own executor
    }
}
```

#### 2. Flow::Subscriber
**Purpose:** Consumer of data with backpressure support
**Key Features:**
- Implements request/response backpressure
- Tracks demand via `$count` and `$request_size`
- Invokes consumer function on each element

```perl
class Flow::Subscriber {
    field $request_size :param :reader = 1;
    field $consumer :param :reader;
    field $subscription;
    field $count;
}
```

#### 3. Flow::Subscription
**Purpose:** Mediator between Publisher and Subscriber
**Key Features:**
- Manages backpressure via `$requested` counter
- Buffers elements when subscriber not ready
- Schedules callbacks via executor's `next_tick()`

```perl
class Flow::Subscription {
    field $publisher  :param :reader;
    field $subscriber :param :reader;
    field $executor   :param :reader;  # Uses publisher's executor

    field $requested = 0;
    field @buffer;
}
```

#### 4. Flow::Operation
**Purpose:** Base class for transformation operations (Map, Grep, etc.)
**Key Features:**
- Acts as both Subscriber (upstream) and Publisher (downstream)
- Creates own Executor in ADJUST block (Operation.pm:16)
- Chains executors via `set_next()` for coordinated execution
- Abstract `apply()` method for subclasses to implement

```perl
class Flow::Operation {
    field $executor   :reader;  # Own executor
    field $downstream :reader;  # Subscription to next stage
    field $upstream   :reader;  # Subscription from previous stage

    ADJUST {
        $executor = Executor->new;  # Each operation gets own executor
    }

    method on_subscribe ($s) {
        $upstream = $s;
        $upstream->executor->set_next( $executor );  # Chain executors!
        $upstream->request(1);
    }
}
```

#### 5. Executor
**Purpose:** Event loop for asynchronous callback execution
**Key Features:**
- Queue-based callback execution (`@callbacks`)
- Executor chaining via `$next` field
- Cycle detection in `set_next()`
- `run()` processes chain until all executors done

```perl
class Executor {
    field $next :param :reader = undef;
    field @callbacks;

    method set_next ($n) {
        # Cycle detection logic
        # ...
        $next = $n;
    }

    method next_tick ($f) {
        push @callbacks => $f;
    }

    method run {
        my $t = $self;
        while (blessed $t && $t isa Executor) {
            $t = $t->tick;
            if (!$t) {
                $t = $self->find_next_undone;
            }
        }
    }
}
```

### Execution Flow

1. **Setup Phase:**
   ```
   Publisher -> Operation1 -> Operation2 -> Subscriber

   Executors:
   pub_exe -> op1_exe -> op2_exe
   ```

2. **Data Flow:**
   ```
   Publisher.submit(value)
     -> buffered
     -> next_tick(drain_buffer)
     -> Subscription.offer(value)
     -> next_tick(drain_buffer)
     -> Subscription.on_next(value)
     -> next_tick(Subscriber.on_next)
     -> Operation1.on_next(value)
     -> next_tick(Operation1.apply)
     -> Operation1.submit(transformed)
     -> ... continues downstream
   ```

3. **Executor Coordination:**
   - Each component schedules work via `next_tick()`
   - Executor.run() processes callbacks in order
   - When one executor done, moves to `$next` via chaining
   - Backpressure via request/offer pattern

### Design Philosophy

**Reactive Streams Standard:** Flow implements the Reactive Streams specification with:
- Asynchronous event-driven processing
- Backpressure (subscriber controls rate)
- Chain of responsibility (Publisher -> Operations -> Subscriber)
- Decentralized executors (each component owns its event loop)

**Key Insight:** This is a **callback-driven, backpressure-controlled** system, not a time-based system.

---

## Part 2: ScheduledExecutor Analysis

### Architecture

```perl
class ScheduledExecutor :isa(Executor) {
    field $current_time = 0;
    field $next_timer_id = 1;
    field @timers;  # [expiry, id, callback, cancelled]

    method schedule_delayed($callback, $delay_ticks) {
        # Insert timer in sorted order
    }

    method run {
        while (!$self->is_done || @timers) {
            # Process queued callbacks first
            if (!$self->is_done) {
                $self->tick;
                next;
            }

            # Advance time to next timer
            my $next_expiry = $self->_find_next_expiry;
            if (defined $next_expiry && $next_expiry > $current_time) {
                $current_time = $next_expiry;
                # Fire timers at this time
            }
        }
    }
}
```

### Key Differences from Executor

1. **Time Model:**
   - Executor: No concept of time, processes callbacks ASAP
   - ScheduledExecutor: Explicit time model, advances between callbacks

2. **run() Behavior:**
   - Executor: `run()` processes all callbacks, returns when done
   - ScheduledExecutor: `run()` advances time, fires timers, processes callbacks

3. **Callback Scheduling:**
   - Executor: `next_tick($f)` - run on next tick
   - ScheduledExecutor: `schedule_delayed($f, $delay)` - run after time delay

### Current Usage

**ScheduledExecutor is currently used ONLY with Promise:**
- `Promise->timeout($delay, $executor)` - timeout after N ticks
- `Promise->delay($value, $delay, $executor)` - resolve after N ticks

**NOT used with Flow at all.**

---

## Part 3: Integration Points Analysis

### Option 1: Replace Executor with ScheduledExecutor Everywhere

**Approach:** Make Flow::Publisher and Flow::Operation use ScheduledExecutor instead of Executor

**Problems:**
1. **run() Override Incompatibility:**
   - ScheduledExecutor.run() advances time between callbacks
   - Executor.run() just processes callbacks
   - Chained executors expect Executor.run() semantics
   - If operation's executor advances time, breaks coordination

2. **Executor Chaining:**
   ```perl
   # In Operation.on_subscribe():
   $upstream->executor->set_next( $executor );
   ```
   - This chains executors for coordinated processing
   - ScheduledExecutor's run() advances time in the middle of chain
   - Would cause timing issues between stages

3. **Unnecessary Complexity:**
   - Flow doesn't need time simulation
   - Adding time tracking to every operation is overhead
   - Breaks separation of concerns

**Verdict:** ❌ Bad idea

### Option 2: Shared ScheduledExecutor for Flow Pipeline

**Approach:** Pass a single ScheduledExecutor to all Flow components

**Current Issue:**
- Publisher and Operation create executors in ADJUST block
- No way to pass executor from outside currently

**Would Require:**
```perl
# Modify Publisher to accept executor parameter
class Flow::Publisher {
    field $executor :param :reader = undef;

    ADJUST {
        $executor //= Executor->new;  # Default if not provided
    }
}

# Similar changes to Operation
```

**Benefits:**
- All Flow components share one event loop
- Could add time-based scheduling if needed

**Problems:**
- Still have ScheduledExecutor.run() issue with time advancement
- Requires API changes to Publisher/Operation
- Mixing reactive streams with time simulation is conceptually odd

**Verdict:** ⚠️ Possible but questionable

### Option 3: Time-Based Flow Operations

**Approach:** Create Flow operations like Flow::Operation::Delay, Flow::Operation::Throttle, etc.

**Example:**
```perl
class Flow::Operation::Delay :isa(Flow::Operation) {
    field $delay_ticks :param;
    field $scheduled_executor :param;

    method apply ($e) {
        $scheduled_executor->schedule_delayed(sub {
            $self->submit($e);
        }, $delay_ticks);
    }
}
```

**Benefits:**
- Specific operations that need time get ScheduledExecutor
- Rest of Flow stays simple with regular Executor
- Clean separation of concerns

**Problems:**
- Flow operations expect synchronous apply()
- Delaying in apply() breaks backpressure contract
- Operation's executor and ScheduledExecutor would be different
- Coordination between two event loops is complex

**Verdict:** ⚠️ Conceptually appealing but technically problematic

### Option 4: Keep Flow and ScheduledExecutor Separate

**Approach:** Flow and ScheduledExecutor serve different purposes, don't force integration

**Flow's Purpose:**
- Reactive stream processing
- Backpressure management
- Asynchronous callback coordination
- Real-time event processing

**ScheduledExecutor's Purpose:**
- Time-based simulation
- Promise timeouts and delays
- Testing time-dependent code
- Scheduled callbacks in controlled time

**Benefits:**
- Each system optimized for its use case
- No forced integration complexity
- Clear separation of concerns
- Both can coexist in same program

**Example Usage:**
```perl
# Use Flow for reactive streams
my $publisher = Flow->from( Flow::Publisher->new )
    ->map(sub { $_ * 2 })
    ->to(sub { say $_ })
    ->build;
$publisher->start;

# Use ScheduledExecutor for time-based logic
my $executor = ScheduledExecutor->new;
my $promise = Promise->delay("data", 100, $executor)
    ->timeout(200, $executor)
    ->then(sub { say $_ });
$executor->run;
```

**Verdict:** ✅ **RECOMMENDED**

---

## Part 4: Design Inconsistencies & Observations

### 1. Executor Proliferation

**Observation:** Each Publisher and Operation creates its own Executor

**Current Pattern:**
```perl
# In grey::static codebase
Publisher creates Executor    # Publisher.pm:16
Operation creates Executor    # Operation.pm:16
(repeated for every operation in pipeline)
```

**From Different Projects:**
- Flow architecture likely from one project
- Executor implementation from another
- Stitched together via `set_next()` chaining

**Questions:**
1. Is executor-per-component necessary?
2. Could shared executor simplify design?
3. Is chaining overhead worth the decentralization?

**Analysis:**
- **Pro (current):** Each component independent, testable in isolation
- **Con (current):** Memory overhead, coordination complexity
- **Pro (shared):** Simpler, less overhead, centralized control
- **Con (shared):** Tighter coupling, harder to test components independently

**No clear winner - tradeoff depends on priorities**

### 2. Stream vs Flow Time Operations

**Inconsistency Observed:**

**Stream has time operations:** (lib/grey/static/stream/Stream.pm)
- `throttle($min_delay, $executor)`
- `debounce($quiet_delay, $executor)`
- `timeout($timeout_delay, $executor)`

**Flow has no time operations:**
- Only Map and Grep currently

**Analysis:**
- Stream is pull-based (lazy), time operations work naturally
- Flow is push-based (reactive), time operations complicate backpressure
- Different semantic models → different feature sets

**This is actually GOOD design** - each system has features that fit its model

### 3. Promise Integration

**Current State:**
- Promise works with ScheduledExecutor ✅
- Promise has `timeout()` and `delay()` ✅
- Promise NOT integrated with Flow ❌

**Potential Integration:**
```perl
# Hypothetical: Flow operations return Promises?
Flow->from($publisher)
    ->map(sub { ... })
    ->to_promise()
    ->then(sub { ... });
```

**Analysis:**
- Flow is about streams (multiple values)
- Promise is about single async value
- Integration unclear - what does "Flow->to_promise" mean?
- Maybe: `->to_future()` that resolves when stream completes?

**Not a priority** - different abstractions

### 4. Executor from Different Projects

**Evidence:**
1. **Executor.pm** - Clean, simple event loop
2. **Flow.pm** - Reactive Streams pattern (Java-inspired?)
3. **ScheduledExecutor.pm** - Added recently for timer integration
4. **Promise.pm** - Promises/A+-style API

**These came from different contexts:**
- Executor: General-purpose event loop
- Flow: Reactive Streams specification implementation
- ScheduledExecutor: Timer/simulation framework
- Promise: Async/await style programming

**Integration Strategy:** They were stitched together via common interfaces (Executor base class, callback patterns)

**This is GOOD:** Reusing components from different projects is pragmatic. Just need to be aware of impedance mismatches.

---

## Part 5: Recommendations

### Short Term: No Flow Integration Needed

**Recommendation:** Keep Flow and ScheduledExecutor separate for now

**Rationale:**
1. Flow doesn't need time simulation
2. ScheduledExecutor's time advancement doesn't fit Flow's executor chaining
3. Stream already has time operations for pull-based use cases
4. Promise + ScheduledExecutor works well for async time-based code

**Action Items:**
- ✅ Document that Flow is for reactive streams, not time-based operations
- ✅ Document that ScheduledExecutor is for Promises and testing
- ✅ Add examples showing both used in same program (complementary, not integrated)

### Medium Term: Consider Flow Time Operations (Optional)

**If future requirements demand time-based Flow operations:**

**Approach:** Hybrid executor model
```perl
class Flow::Operation::Throttle :isa(Flow::Operation) {
    field $min_delay :param;
    field $last_emit :reader = 0;

    # Use executor's time tracking instead of ScheduledExecutor
    method apply ($e) {
        my $current_time = $executor->current_time;  # Need to add this
        if ($current_time - $last_emit >= $min_delay) {
            $self->submit($e);
            $last_emit = $current_time;
        }
    }
}
```

**Would require:**
1. Add `current_time` tracking to base Executor
2. Implement time-based Flow operations using executor time
3. Keep ScheduledExecutor.run() override separate

**Priority:** Low - Stream already has these operations

### Long Term: Consider Unified Executor

**If executor-per-component proves problematic:**

**Approach:** Optional shared executor
```perl
# Allow passing executor to Publisher/Operation
my $executor = Executor->new;
my $publisher = Flow::Publisher->new(executor => $executor);
my $op = Flow::Operation::Map->new(f => $f, executor => $executor);
```

**Benefits:**
- Reduced memory overhead
- Simpler execution model
- Centralized control

**Tradeoffs:**
- Tighter coupling
- Need to refactor ADJUST blocks
- May break existing code

**Priority:** Low - current design works

### Documentation Priority

**High Priority:**
1. Document Flow architecture (reactive streams, backpressure)
2. Document ScheduledExecutor (time simulation, Promise integration)
3. Document when to use each
4. Example: Using both in same program

**Medium Priority:**
1. Document executor chaining mechanism
2. Document why time operations not in Flow
3. Benchmark executor overhead if needed

---

## Part 6: Benchmarking Plan (Future)

### Performance Questions to Answer

1. **Executor overhead:**
   - Cost of executor-per-component vs shared executor
   - Memory usage with long pipelines
   - Callback scheduling overhead

2. **ScheduledExecutor performance:**
   - Timer queue performance (current O(n) insertion)
   - Impact of min-heap optimization
   - Time advancement overhead

3. **Flow throughput:**
   - Elements/second through pipeline
   - Backpressure impact on throughput
   - Comparison with Stream (pull-based)

### Benchmark Scenarios

```perl
# Scenario 1: Long pipeline
Publisher -> Map -> Grep -> Map -> Map -> Grep -> Subscriber
(Measure: throughput, memory, executor count impact)

# Scenario 2: Many concurrent timers
ScheduledExecutor with 1000 timers
(Measure: insertion time, cancellation time, memory)

# Scenario 3: Stream vs Flow
Same transformation pipeline in both
(Measure: which is faster for different use cases)
```

**Priority:** Medium - only if performance issues arise

---

## Conclusion

**Key Insights:**

1. **Flow and ScheduledExecutor serve different purposes** - reactive streams vs time simulation
2. **Current separation is good design** - don't force integration
3. **Stream has time operations, Flow doesn't** - this is intentional and correct
4. **Components from different projects** - aware of impedance mismatches
5. **Executor-per-component pattern** - tradeoff between independence and overhead

**Recommended Next Steps:**

1. ✅ Update TIMER_INTEGRATION_STATUS.md (Done)
2. ✅ Deep dive complete
3. 📝 Document architecture and usage patterns
4. 📝 Create examples showing Flow + ScheduledExecutor used together (complementary)
5. 📝 Add POD documentation to all concurrency components
6. 🧪 Write integration tests (Flow + Promise scenarios)
7. 📊 Benchmark if performance concerns arise (optional)

**No urgent integration work needed.** Focus on documentation and examples to clarify the design.
