# Yakt Actor System Integration Plan

This document details the plan for merging the Yakt Actor System into grey::static as the `concurrency::actor` feature.

## Table of Contents

1. [Overview](#1-overview)
2. [Architecture](#2-architecture)
3. [Phase 1: Foundation Alignment](#3-phase-1-foundation-alignment)
4. [Phase 2: Core Actor Port](#4-phase-2-core-actor-port)
5. [Phase 3: System Infrastructure](#5-phase-3-system-infrastructure)
6. [Phase 4: IO Integration](#6-phase-4-io-integration)
7. [Phase 5: Bridge Classes](#7-phase-5-bridge-classes)
8. [Phase 6: Documentation & Examples](#8-phase-6-documentation--examples)
9. [File Mapping](#9-file-mapping)
10. [API Design](#10-api-design)
11. [Testing Strategy](#11-testing-strategy)
12. [Migration Considerations](#12-migration-considerations)

---

## 1. Overview

### 1.1 Goals

- Integrate Yakt's actor-based concurrency into grey::static
- Unify timer/scheduling infrastructure around `ScheduledExecutor`
- Enable seamless interop between Actors, Flow, and Promises
- Maintain grey::static's feature loader patterns
- Preserve Yakt's proven API and semantics

### 1.2 Non-Goals

- Breaking changes to existing grey::static APIs
- Distributed actors (network transparency) - future work
- Thread-based parallelism - stay cooperative single-threaded

### 1.3 Success Criteria

- All existing Yakt tests pass after port
- All existing grey::static tests pass
- New integration tests demonstrate Actor+Flow+Promise interop
- Clean feature loading: `use grey::static qw[ concurrency::actor ]`
- Documentation covers all actor features

---

## 2. Architecture

### 2.1 Target Feature Structure

```
use grey::static qw[
    concurrency::util      # Executor, ScheduledExecutor, Promise
    concurrency::reactive  # Flow, Publisher, Subscriber, Operations
    concurrency::actor     # Actor, ActorSystem, Props, Ref, Behavior
    concurrency::io        # IO Selectors (async IO)
];
```

### 2.2 Directory Structure

```
lib/grey/static/
├── concurrency.pm                    # Feature router (existing)
└── concurrency/
    ├── util/                         # Existing
    │   ├── Executor.pm
    │   ├── ScheduledExecutor.pm
    │   └── Promise.pm
    ├── reactive/                     # Existing (Flow/)
    │   └── Flow/
    │       ├── Publisher.pm
    │       ├── Subscriber.pm
    │       ├── Subscription.pm
    │       ├── Operation.pm
    │       ├── Operation/
    │       └── Publishers.pm
    ├── actor/                        # NEW - from Yakt
    │   ├── Actor.pm
    │   ├── ActorSystem.pm
    │   ├── Behavior.pm
    │   ├── Context.pm
    │   ├── Message.pm
    │   ├── Props.pm
    │   ├── Ref.pm
    │   ├── Mailbox.pm
    │   ├── Signals/
    │   │   ├── Started.pm
    │   │   ├── Stopping.pm
    │   │   ├── Stopped.pm
    │   │   ├── Terminated.pm
    │   │   ├── Ready.pm
    │   │   └── Restarting.pm
    │   ├── Supervisors/
    │   │   ├── Stop.pm
    │   │   ├── Resume.pm
    │   │   ├── Retry.pm
    │   │   └── Restart.pm
    │   └── Internal/
    │       ├── Root.pm
    │       ├── System.pm
    │       ├── Users.pm
    │       └── DeadLetterQueue.pm
    └── io/                           # NEW - from Yakt
        ├── Selector.pm
        └── Selector/
            ├── Socket.pm
            └── Stream.pm
```

### 2.3 Class Naming

| Yakt Class | Grey::static Class |
|------------|-------------------|
| `Yakt::Actor` | `Actor` |
| `Yakt::System` | `ActorSystem` |
| `Yakt::Context` | `Actor::Context` |
| `Yakt::Ref` | `Actor::Ref` |
| `Yakt::Props` | `Actor::Props` |
| `Yakt::Behavior` | `Actor::Behavior` |
| `Yakt::Message` | `Actor::Message` |
| `Yakt::System::Mailbox` | `Actor::Mailbox` |
| `Yakt::System::Signals::*` | `Actor::Signals::*` |
| `Yakt::System::Supervisors::*` | `Actor::Supervisors::*` |
| `Yakt::System::Timers` | Use `ScheduledExecutor` |
| `Yakt::System::IO::*` | `IO::Selector::*` |

---

## 3. Phase 1: Foundation Alignment

**Goal**: Ensure Yakt can use grey::static's `ScheduledExecutor` for timing.

### 3.1 Timer API Compatibility

Yakt's timer API:
```perl
$context->schedule(
    after    => 1.5,      # seconds (float)
    callback => sub { }
);
# Returns timer object with ->cancel() method
```

ScheduledExecutor API:
```perl
my $id = $executor->schedule_delayed(
    sub { },              # callback
    1500                  # milliseconds (int)
);
$executor->cancel_scheduled($id);
```

### 3.2 Tasks

1. **Create Timer wrapper class** (`Actor::Timer`)
   ```perl
   class Actor::Timer {
       field $executor :param;
       field $timer_id :param;

       method cancel {
           $executor->cancel_scheduled($timer_id);
       }
   }
   ```

2. **Add `schedule()` method to Context** that wraps ScheduledExecutor
   ```perl
   method schedule (%opts) {
       my $delay_ms = $opts{after} * 1000;  # Convert to ms
       my $id = $system->executor->schedule_delayed(
           $opts{callback},
           $delay_ms
       );
       return Actor::Timer->new(
           executor => $system->executor,
           timer_id => $id
       );
   }
   ```

3. **Remove Yakt::System::Timers** - replaced by ScheduledExecutor

4. **Update ActorSystem event loop** to use ScheduledExecutor::tick()

### 3.3 Validation

- Port Yakt timer tests to verify behavior preserved
- Ensure timer precision (ms) matches original

---

## 4. Phase 2: Core Actor Port

**Goal**: Port the core actor classes with minimal modification.

### 4.1 Classes to Port (in order)

1. **Actor::Message** (base message class)
   - Simple port, no dependencies
   - Fields: `$reply_to`, `$sender`, `$payload`

2. **Actor::Behavior** (dispatch tables)
   - Port receivers/handlers hash structure
   - Methods: `receive_message()`, `receive_signal()`

3. **Actor** (base actor class)
   - Port attribute handling (`@Receive`, `@Signal`)
   - Methods: `become()`, `unbecome()`, `behavior_for()`
   - `MODIFY_CODE_ATTRIBUTES` for collecting handlers

4. **Actor::Props** (actor configuration)
   - Fields: `$class`, `$args`, `$alias`, `$supervisor`
   - Method: `with_supervisor()` fluent builder

5. **Actor::Ref** (actor reference)
   - Fields: `$pid`, `$context`
   - Methods: `send()`, `pid()`, `context()`

6. **Actor::Context** (actor's system interface)
   - Methods: `self()`, `parent()`, `children()`, `spawn()`, `send()`, `stop()`, `watch()`, `schedule()`

### 4.2 Porting Guidelines

1. **Package naming**: Replace `Yakt::` with appropriate grey::static name
2. **Remove p7 artifacts**: `use module`, `LOG`, `TICK` statements
3. **Preserve formatting**: Keep original code style
4. **Update imports**: Use grey::static's feature loader where applicable

### 4.3 Attribute System

The `@Receive` and `@Signal` attributes are central to Yakt's API. These use Perl's attribute system:

```perl
class MyActor :isa(Actor) {
    method handle_foo :Receive(FooMessage) ($ctx, $msg) { }
    method on_started :Signal(Actor::Signals::Started) ($ctx, $sig) { }
}
```

This requires:
- `MODIFY_CODE_ATTRIBUTES` in Actor base class
- `%RECEIVERS` and `%HANDLERS` class variables
- Compile-time collection of handlers

---

## 5. Phase 3: System Infrastructure

**Goal**: Port the ActorSystem and its internal components.

### 5.1 Classes to Port

1. **Actor::Mailbox** (lifecycle state machine)
   - States: STARTING, ALIVE, RUNNING, SUSPENDED, STOPPING, STOPPED, RESTARTING
   - Methods: `tick()`, `enqueue_message()`, `notify()`, `stop()`, `restart()`

2. **Actor::Signals::*** (lifecycle signals)
   - `Started` - Actor initialized
   - `Stopping` - Actor shutting down
   - `Stopped` - Actor stopped
   - `Terminated` - Watched actor terminated
   - `Ready` - Custom init sequencing
   - `Restarting` - Actor restarting

3. **Actor::Supervisors::*** (error handling strategies)
   - `Stop` - Halt on error (default)
   - `Resume` - Skip failed message
   - `Retry` - Re-deliver message
   - `Restart` - Restart actor

4. **ActorSystem** (main entry point)
   - Fields: `%lookup`, `@mailboxes`, `$executor` (ScheduledExecutor)
   - Methods: `init()`, `loop_until_done()`, `spawn_actor()`, `shutdown()`

5. **Internal system actors**
   - `Actor::Internal::Root` - Orchestrates startup
   - `Actor::Internal::System` - System actor parent
   - `Actor::Internal::Users` - User actor parent
   - `Actor::Internal::DeadLetterQueue` - Unhandled messages

### 5.2 Event Loop Integration

The key integration point is the event loop. Current Yakt loop:

```perl
method loop_until_done {
    while (1) {
        $self->tick;
        # Check exit conditions...
    }
}

method tick {
    $timers->tick;           # Fire timers
    $self->run_mailboxes;    # Process actors
    $io->tick($timeout);     # Poll IO
}
```

Updated to use ScheduledExecutor:

```perl
method tick {
    $executor->tick;         # Fire scheduled callbacks (timers)
    $self->run_mailboxes;    # Process actors
    $io->tick($timeout);     # Poll IO
}
```

### 5.3 Mailbox Processing

Preserve Yakt's fairness model:
- All ready mailboxes run each tick
- prepare() → tick() → finish() cycle
- Unhandled messages → dead letter queue

---

## 6. Phase 4: IO Integration

**Goal**: Port Yakt's async IO selector system.

### 6.1 Classes to Port

1. **IO::Selector** (base selector class)
   - Fields: `$ref`, `$fh`
   - Methods: `fh()`, `ref()`

2. **IO::Selector::Socket** (TCP/UDP sockets)
   - Signals: CanRead, CanWrite, IsConnected, GotError, CanAccept

3. **IO::Selector::Stream** (file handles, pipes)
   - Signals: CanRead, CanWrite

4. **IO Signals**
   - `Actor::Signals::IO::CanRead`
   - `Actor::Signals::IO::CanWrite`
   - `Actor::Signals::IO::IsConnected`
   - `Actor::Signals::IO::GotError`
   - `Actor::Signals::IO::CanAccept`

### 6.2 IO Manager

Port `Yakt::System::IO` as `Actor::IO::Manager`:

```perl
class Actor::IO::Manager {
    field @readers;
    field @writers;

    method add_selector ($selector) { }
    method remove_selector ($selector) { }
    method tick ($timeout) {
        my ($r, $w, $e) = IO::Select::select(...);
        # Dispatch IO signals to actors
    }
}
```

### 6.3 Feature Loading

New feature: `concurrency::io`

```perl
use grey::static qw[ concurrency::io ];
# Loads: IO::Selector, IO::Selector::Socket, IO::Selector::Stream
```

---

## 7. Phase 5: Bridge Classes

**Goal**: Create interop classes between Actors, Flow, and Promises.

### 7.1 Actor → Flow Bridge

**ActorPublisher**: Publishes actor messages to Flow pipeline

```perl
class Actor::Flow::ActorPublisher :isa(Flow::Publisher) {
    field $actor_ref :param;
    field $message_filter :param = undef;  # Optional Predicate

    # Actor sends messages here, we publish to subscribers
    method on_actor_message ($message) {
        return if $message_filter && !$message_filter->test($message);
        $self->submit($message);
    }
}
```

### 7.2 Flow → Actor Bridge

**FlowSubscriberActor**: Actor that subscribes to Flow

```perl
class Actor::Flow::FlowSubscriberActor :isa(Actor) {
    field $publisher :param;
    field $handler :param;  # Consumer for messages

    method on_started :Signal(Actor::Signals::Started) ($ctx, $sig) {
        Flow->from($publisher)
            ->to(Consumer->new(f => sub ($value) {
                $handler->accept($value);
            }))
            ->build
            ->start;
    }
}
```

### 7.3 Promise-based Ask Pattern

**Actor::Ask**: Request-response with Promise

```perl
class Actor::Ask {
    method ask ($actor_ref, $message, %opts) {
        my $executor = $opts{executor} // ScheduledExecutor->new;
        my $timeout_ms = ($opts{timeout} // 30) * 1000;

        my $promise = Promise->new(executor => $executor);

        # Create one-shot reply actor
        my $reply_actor = $opts{system}->spawn_anonymous(sub ($ctx, $response) {
            $promise->resolve($response);
            $ctx->stop;
        });

        # Send with reply_to
        $actor_ref->send($message->with_reply_to($reply_actor));

        return $promise->timeout($timeout_ms, $executor);
    }
}
```

### 7.4 Supervised Flow Operations

**Actor::Flow::SupervisedPipeline**: Flow with actor supervision

```perl
class Actor::Flow::SupervisedPipeline :isa(Actor) {
    field $pipeline :param;  # Flow builder
    field $supervisor :param = Actor::Supervisors::Restart->new;

    method on_started :Signal(Actor::Signals::Started) ($ctx, $sig) {
        $self->start_pipeline($ctx);
    }

    method start_pipeline ($ctx) {
        try {
            $pipeline->build->start;
        } catch ($e) {
            my $action = $supervisor->supervise($ctx, $e);
            if ($action == RESTART) {
                $ctx->schedule(
                    after => 1,
                    callback => sub { $self->start_pipeline($ctx) }
                );
            }
        }
    }
}
```

---

## 8. Phase 6: Documentation & Examples

### 8.1 Documentation Files

1. **docs/concurrency-actor-guide.md**
   - Actor basics
   - Message handling
   - Lifecycle signals
   - Supervision strategies
   - Behavior switching

2. **docs/concurrency-actor-api.md**
   - Complete API reference
   - All classes and methods

3. **docs/concurrency-integration-patterns.md**
   - Actor + Flow patterns
   - Actor + Promise patterns
   - Event loop coordination

4. **Update CLAUDE.md**
   - Add `concurrency::actor` to feature list
   - Add `concurrency::io` to feature list
   - Document new classes

### 8.2 Examples

1. **examples/actor/hello-world.pl**
   ```perl
   use grey::static qw[ concurrency::actor ];

   class Greeter :isa(Actor) {
       method greet :Receive(Greet) ($ctx, $msg) {
           say "Hello, " . $msg->name . "!";
           $ctx->stop;
       }
   }

   my $sys = ActorSystem->new->init(sub ($ctx) {
       my $greeter = $ctx->spawn(Actor::Props->new(class => 'Greeter'));
       $greeter->send(Greet->new(name => 'World'));
   });

   $sys->loop_until_done;
   ```

2. **examples/actor/ping-pong.pl** - Two actors messaging

3. **examples/actor/supervision.pl** - Error handling demo

4. **examples/actor/flow-integration.pl** - Actor + Flow pipeline

5. **examples/actor/chat-server.pl** - IO selectors demo

---

## 9. File Mapping

### 9.1 Yakt → Grey::static File Mapping

| Yakt Source | Grey::static Target |
|-------------|---------------------|
| `lib/Yakt/Actor.pm` | `lib/grey/static/concurrency/actor/Actor.pm` |
| `lib/Yakt/System.pm` | `lib/grey/static/concurrency/actor/ActorSystem.pm` |
| `lib/Yakt/Context.pm` | `lib/grey/static/concurrency/actor/Context.pm` |
| `lib/Yakt/Ref.pm` | `lib/grey/static/concurrency/actor/Ref.pm` |
| `lib/Yakt/Props.pm` | `lib/grey/static/concurrency/actor/Props.pm` |
| `lib/Yakt/Behavior.pm` | `lib/grey/static/concurrency/actor/Behavior.pm` |
| `lib/Yakt/Message.pm` | `lib/grey/static/concurrency/actor/Message.pm` |
| `lib/Yakt/System/Mailbox.pm` | `lib/grey/static/concurrency/actor/Mailbox.pm` |
| `lib/Yakt/System/Timers.pm` | **REMOVED** (use ScheduledExecutor) |
| `lib/Yakt/System/IO.pm` | `lib/grey/static/concurrency/io/Manager.pm` |
| `lib/Yakt/System/IO/Selector.pm` | `lib/grey/static/concurrency/io/Selector.pm` |
| `lib/Yakt/System/IO/Selector/*.pm` | `lib/grey/static/concurrency/io/Selector/*.pm` |
| `lib/Yakt/System/Signals/*.pm` | `lib/grey/static/concurrency/actor/Signals/*.pm` |
| `lib/Yakt/System/Supervisors/*.pm` | `lib/grey/static/concurrency/actor/Supervisors/*.pm` |
| `lib/Yakt/System/Actors/*.pm` | `lib/grey/static/concurrency/actor/Internal/*.pm` |

### 9.2 Test File Mapping

| Yakt Test | Grey::static Test |
|-----------|-------------------|
| `t/000-sanity/*.t` | `t/grey/static/04-concurrency/actor/000-sanity/*.t` |
| `t/001-basic/*.t` | `t/grey/static/04-concurrency/actor/001-basic/*.t` |
| `t/002-signals/*.t` | `t/grey/static/04-concurrency/actor/002-signals/*.t` |
| `t/003-supervision/*.t` | `t/grey/static/04-concurrency/actor/003-supervision/*.t` |
| `t/010-io/*.t` | `t/grey/static/04-concurrency/io/*.t` |

---

## 10. API Design

### 10.1 Feature Loader

Update `lib/grey/static/concurrency.pm`:

```perl
sub import {
    my ($class, @subfeatures) = @_;
    return unless @subfeatures;

    for my $subfeature (@subfeatures) {
        if ($subfeature eq 'util') {
            # Existing: Executor, ScheduledExecutor, Promise
        }
        elsif ($subfeature eq 'reactive') {
            # Existing: Flow, Publisher, Subscriber, etc.
        }
        elsif ($subfeature eq 'actor') {
            use lib File::Basename::dirname(__FILE__) . '/concurrency/actor';
            load_module('Actor');
            load_module('ActorSystem');
            load_module('Actor::Props');
            load_module('Actor::Ref');
            load_module('Actor::Context');
            load_module('Actor::Behavior');
            load_module('Actor::Message');
            load_module('Actor::Mailbox');
            # Signals
            load_module('Actor::Signals::Started');
            load_module('Actor::Signals::Stopping');
            load_module('Actor::Signals::Stopped');
            load_module('Actor::Signals::Terminated');
            load_module('Actor::Signals::Ready');
            load_module('Actor::Signals::Restarting');
            # Supervisors
            load_module('Actor::Supervisors::Stop');
            load_module('Actor::Supervisors::Resume');
            load_module('Actor::Supervisors::Retry');
            load_module('Actor::Supervisors::Restart');
        }
        elsif ($subfeature eq 'io') {
            use lib File::Basename::dirname(__FILE__) . '/concurrency/io';
            load_module('IO::Selector');
            load_module('IO::Selector::Socket');
            load_module('IO::Selector::Stream');
            load_module('IO::Manager');
            # IO Signals
            load_module('Actor::Signals::IO::CanRead');
            load_module('Actor::Signals::IO::CanWrite');
            load_module('Actor::Signals::IO::IsConnected');
            load_module('Actor::Signals::IO::GotError');
            load_module('Actor::Signals::IO::CanAccept');
        }
        else {
            die "Unknown concurrency subfeature: $subfeature";
        }
    }
}
```

### 10.2 Exported Names

When `concurrency::actor` is loaded, these become globally available:

**Classes:**
- `Actor` - Base actor class
- `ActorSystem` - System entry point
- `Actor::Props` - Actor configuration
- `Actor::Ref` - Actor reference
- `Actor::Context` - Actor's system interface
- `Actor::Behavior` - Message dispatch
- `Actor::Message` - Base message class
- `Actor::Mailbox` - Lifecycle state machine

**Signals:**
- `Actor::Signals::Started`
- `Actor::Signals::Stopping`
- `Actor::Signals::Stopped`
- `Actor::Signals::Terminated`
- `Actor::Signals::Ready`
- `Actor::Signals::Restarting`

**Supervisors:**
- `Actor::Supervisors::Stop`
- `Actor::Supervisors::Resume`
- `Actor::Supervisors::Retry`
- `Actor::Supervisors::Restart`

### 10.3 Convenience Aliases (Optional)

Consider adding short aliases for common types:

```perl
# In actor feature loader
*Props = \&Actor::Props::new;
*Started = 'Actor::Signals::Started';
*Stopped = 'Actor::Signals::Stopped';
# etc.
```

---

## 11. Testing Strategy

### 11.1 Test Categories

1. **Unit Tests** - Individual class behavior
   - Actor attribute parsing
   - Behavior dispatch
   - Mailbox state transitions
   - Props configuration

2. **Integration Tests** - Component interaction
   - Actor spawning and messaging
   - Signal delivery
   - Supervision hierarchy
   - Timer scheduling

3. **System Tests** - Full system behavior
   - Event loop completion
   - Shutdown sequences
   - Dead letter handling

4. **Bridge Tests** - Cross-feature integration
   - Actor + Flow
   - Actor + Promise
   - Actor + ScheduledExecutor

### 11.2 Test Porting

Port all 49 Yakt tests, organized by category:

```
t/grey/static/04-concurrency/
├── actor/
│   ├── 000-sanity/
│   │   ├── 001-load.t
│   │   ├── 002-actor-class.t
│   │   └── 003-props.t
│   ├── 001-basic/
│   │   ├── 010-spawn.t
│   │   ├── 011-messaging.t
│   │   ├── 012-lifecycle.t
│   │   └── 013-behavior.t
│   ├── 002-signals/
│   │   ├── 020-started.t
│   │   ├── 021-stopping.t
│   │   ├── 022-terminated.t
│   │   └── 023-restarting.t
│   ├── 003-supervision/
│   │   ├── 030-stop.t
│   │   ├── 031-resume.t
│   │   ├── 032-retry.t
│   │   └── 033-restart.t
│   └── 004-timers/
│       ├── 040-schedule.t
│       └── 041-cancel.t
├── io/
│   ├── 050-selector.t
│   ├── 051-socket.t
│   └── 052-stream.t
└── bridge/
    ├── 060-actor-flow.t
    ├── 061-actor-promise.t
    └── 062-supervised-flow.t
```

### 11.3 Test Utilities

Create test helpers:

```perl
# t/lib/ActorTestUtils.pm
package ActorTestUtils;

sub spawn_test_actor {
    my ($system, $class, %opts) = @_;
    # Helper for test actor creation
}

sub wait_for_message {
    my ($actor, $type, $timeout) = @_;
    # Helper for async test assertions
}

sub assert_signal_received {
    my ($actor, $signal_type) = @_;
    # Helper for signal testing
}

1;
```

---

## 12. Migration Considerations

### 12.1 Breaking Changes

**None for grey::static users** - This is additive.

**For Yakt users migrating:**
- Package rename: `Yakt::*` → `Actor::*` / `ActorSystem`
- Import change: `use Yakt::System` → `use grey::static qw[ concurrency::actor ]`
- Timer API preserved but backed by ScheduledExecutor

### 12.2 Deprecation Path (if standalone Yakt continues)

If Yakt remains a separate module:
1. Yakt can depend on grey::static for timer infrastructure
2. Or Yakt can remain fully independent
3. No forced migration needed

### 12.3 Version Requirements

- Perl 5.40+ (for `class` feature) - matches Yakt
- Time::HiRes (already required by grey::static)
- IO::Select (for IO feature)

---

## Appendix A: Implementation Checklist

### Phase 1: Foundation Alignment
- [ ] Create `Actor::Timer` wrapper class
- [ ] Verify ScheduledExecutor API compatibility
- [ ] Update timer precision tests
- [ ] Document timer migration

### Phase 2: Core Actor Port
- [ ] Port `Actor::Message`
- [ ] Port `Actor::Behavior`
- [ ] Port `Actor` base class
- [ ] Port `Actor::Props`
- [ ] Port `Actor::Ref`
- [ ] Port `Actor::Context`
- [ ] Verify attribute system works

### Phase 3: System Infrastructure
- [ ] Port `Actor::Mailbox`
- [ ] Port all signals (6 classes)
- [ ] Port all supervisors (4 classes)
- [ ] Port `ActorSystem`
- [ ] Port internal actors (Root, System, Users, DeadLetterQueue)
- [ ] Integrate with ScheduledExecutor
- [ ] Update feature loader

### Phase 4: IO Integration
- [ ] Port `IO::Selector` base
- [ ] Port `IO::Selector::Socket`
- [ ] Port `IO::Selector::Stream`
- [ ] Port `IO::Manager`
- [ ] Port IO signals (5 classes)
- [ ] Update feature loader for `concurrency::io`

### Phase 5: Bridge Classes
- [ ] Implement `Actor::Flow::ActorPublisher`
- [ ] Implement `Actor::Flow::FlowSubscriberActor`
- [ ] Implement `Actor::Ask` (Promise-based)
- [ ] Implement `Actor::Flow::SupervisedPipeline`
- [ ] Write integration tests

### Phase 6: Documentation & Examples
- [ ] Write `docs/concurrency-actor-guide.md`
- [ ] Write `docs/concurrency-actor-api.md`
- [ ] Write `docs/concurrency-integration-patterns.md`
- [ ] Update `CLAUDE.md`
- [ ] Create example scripts (5+)
- [ ] Update README

---

## Appendix B: Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Attribute system incompatibility | Low | High | Test early in Phase 2 |
| Timer precision regression | Medium | Medium | Comprehensive timer tests |
| Event loop deadlocks | Low | High | Careful integration testing |
| Performance regression | Medium | Low | Benchmark before/after |
| API confusion (Actor vs Flow) | Medium | Medium | Clear documentation |

---

## Appendix C: Future Enhancements

After initial integration, consider:

1. **Actor Streaming** - Backpressure-aware actors using Flow protocol
2. **Actor Pools** - Router patterns (round-robin, broadcast, etc.)
3. **Persistence** - Actor state snapshots and recovery
4. **Clustering** - Network-transparent actor references
5. **Metrics** - Actor system observability
6. **Testing DSL** - BDD-style actor testing utilities
