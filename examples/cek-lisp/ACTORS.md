# Actor Integration for CEK Lisp

This document outlines a design for integrating grey::static's actor system into the CEK Lisp interpreter, enabling concurrent programming with message-passing semantics.

## Overview

The actor model provides:
- **Encapsulated state** - Each actor has private mutable state
- **Message passing** - Actors communicate asynchronously via messages
- **Supervision** - Parent actors monitor and restart failed children
- **Location transparency** - ActorRefs abstract over where actors run

grey::static already has a full actor implementation (ported from Yakt):
- `Actor`, `ActorSystem` - Core classes
- `Actor::Ref`, `Actor::Context` - References and execution context
- `Actor::Behavior` - Message dispatch with @Receive/@Signal attributes
- `Actor::Supervisors::*` - Stop, Resume, Retry, Restart strategies
- `Actor::Signals::*` - Started, Stopping, Stopped, Terminated, etc.

## Design Goals

1. **Explicit over implicit** - Clear primitives, macros can add sugar later
2. **Async integration** - Leverage existing Promise/ScheduledExecutor support
3. **Lisp-native feel** - Behaviors defined with lambdas, not Perl attributes
4. **Full supervision** - Expose grey::static's supervision strategies

## Value Types

New value types to wrap grey::static actor objects:

```perl
class ActorSystemVal {
    field $system :param :reader;  # grey::static ActorSystem
    method type { 'actor-system' }
    method is_truthy { 1 }
}

class ActorRefVal {
    field $ref :param :reader;  # grey::static Actor::Ref
    method type { 'actor-ref' }
    method is_truthy { 1 }
}

class BehaviorVal {
    field $behavior :param :reader;  # Wrapped behavior definition
    method type { 'behavior' }
    method is_truthy { 1 }
}

class ActorContextVal {
    field $ctx :param :reader;  # grey::static Actor::Context
    method type { 'actor-context' }
    method is_truthy { 1 }
}
```

## Primitives

### System Management

```lisp
(actor-system)                    ; Create new ActorSystem
                                  ; => ActorSystemVal

(actor-system-shutdown sys)       ; Initiate shutdown
                                  ; => nil

(actor-system-wait sys)           ; Block until shutdown complete
                                  ; => nil (async - returns Promise)
```

### Spawning Actors

```lisp
(spawn sys behavior)              ; Spawn top-level actor
                                  ; => ActorRefVal

(spawn-named sys name behavior)   ; Spawn with name
                                  ; => ActorRefVal

(spawn-child ctx behavior)        ; Spawn as child of current actor
                                  ; => ActorRefVal

(spawn-child-named ctx name behavior)
                                  ; => ActorRefVal
```

### Message Passing

```lisp
(send ref message)                ; Fire-and-forget send
                                  ; => nil (returns immediately)

(ask ref message)                 ; Request-response pattern
                                  ; => Promise that resolves with reply

(ask-timeout ref message ms)      ; Ask with timeout
                                  ; => Promise (rejects on timeout)

(reply ctx value)                 ; Reply to current message sender
                                  ; => nil

(forward ctx ref)                 ; Forward current message to another actor
                                  ; => nil
```

### Behavior Definition

```lisp
(behavior
  (initial-state expr)            ; Initial state value

  (receive pattern handler)       ; Message handler
                                  ; handler: (lambda (ctx state) ...)
                                  ; Returns: new state

  (receive-any handler)           ; Catch-all handler

  (on-signal signal handler)      ; Lifecycle signal handler
                                  ; signal: 'Started, 'Stopping, 'Stopped, etc.
)
; => BehaviorVal
```

### State Transitions

```lisp
(become ctx new-state)            ; Continue with new state, same behavior
                                  ; Called from within handler

(become-with ctx new-state new-behavior)
                                  ; Continue with new state AND new behavior
                                  ; Enables hot code swapping

(stop-self ctx)                   ; Stop the current actor

(stop-child ctx ref)              ; Stop a child actor
```

### Context Accessors

```lisp
(self ctx)                        ; => ActorRefVal of current actor
(sender ctx)                      ; => ActorRefVal of message sender (if any)
(parent ctx)                      ; => ActorRefVal of parent (if any)
(children ctx)                    ; => list of child ActorRefVals
(system-of ctx)                   ; => ActorSystemVal
```

### Supervision

```lisp
(supervisor
  (strategy 'one-for-one)         ; or 'one-for-all, 'rest-for-one
  (max-restarts n)                ; max restarts within window
  (within-ms ms)                  ; time window for restart counting
  (on-failure                     ; what to do on child failure
    (child-pattern strategy))     ; 'stop, 'resume, 'restart, 'escalate
  (children
    (child 'name behavior)        ; child specifications
    (child 'name behavior)))
; => SupervisorBehaviorVal
```

## Bridging Lisp Lambdas to Actor Behaviors

The key challenge is that grey::static's Actor::Behavior uses Perl's attribute system (@Receive, @Signal), but we want to define behaviors with Lisp lambdas.

### Approach: Wrapper Behavior Class

Create a Perl class that wraps Lisp behavior definitions:

```perl
class LispBehavior {
    field $cek :param;           # Reference to CEK machine
    field $executor :param;       # ScheduledExecutor
    field $handlers :param;       # { pattern => LambdaVal }
    field $signal_handlers :param; # { signal => LambdaVal }
    field $initial_state :param;

    method receive($ctx, $msg, $state) {
        # Find matching handler
        my $handler = $self->match_handler($msg);

        # Wrap ctx and state as Lisp values
        my $ctx_val = ActorContextVal->new(ctx => $ctx);
        my $state_val = $self->perl_to_lisp($state);
        my $msg_val = $self->perl_to_lisp($msg);

        # Invoke handler through CEK machine
        my $result = $cek->apply_lambda($handler, [$ctx_val, $state_val, $msg_val]);

        # Result is the new state
        return $self->lisp_to_perl($result);
    }

    method on_signal($ctx, $signal) {
        my $handler = $signal_handlers->{$signal->type};
        return unless $handler;

        my $ctx_val = ActorContextVal->new(ctx => $ctx);
        $cek->apply_lambda($handler, [$ctx_val]);
    }
}
```

### Message Pattern Matching

Simple pattern matching for `receive`:

```lisp
(receive 'increment handler)      ; Match symbol exactly
(receive ('add n) handler)        ; Match list, bind n
(receive-any handler)             ; Match anything
```

Implementation could use:
- Symbol equality for simple patterns
- Destructuring for list patterns
- Priority ordering (specific before general)

## Example: Counter Actor

```lisp
(define counter-behavior
  (behavior
    (initial-state 0)

    (on-signal 'Started
      (lambda (ctx)
        (print "Counter started")))

    (receive 'increment
      (lambda (ctx state)
        (+ state 1)))

    (receive 'decrement
      (lambda (ctx state)
        (- state 1)))

    (receive 'get
      (lambda (ctx state)
        (reply ctx state)
        state))

    (receive 'reset
      (lambda (ctx state)
        0))))

; Usage
(define sys (actor-system))
(define counter (spawn sys counter-behavior))

(send counter 'increment)
(send counter 'increment)
(send counter 'increment)

; ask returns a Promise
(define result (ask counter 'get))
; result resolves to 3
```

## Example: Ping-Pong

```lisp
(define pong-behavior
  (behavior
    (initial-state 0)

    (receive 'ping
      (lambda (ctx state)
        (print "pong!")
        (send (sender ctx) 'pong)
        (+ state 1)))))

(define (ping-behavior pong-ref)
  (behavior
    (initial-state 0)

    (on-signal 'Started
      (lambda (ctx)
        (send pong-ref 'ping)))

    (receive 'pong
      (lambda (ctx state)
        (print "ping!")
        (if (< state 5)
            (begin
              (send pong-ref 'ping)
              (+ state 1))
            (begin
              (print "Done!")
              (stop-self ctx)
              state))))))

(define sys (actor-system))
(define pong (spawn sys pong-behavior))
(define ping (spawn sys (ping-behavior pong)))
(actor-system-wait sys)

; Output:
; pong!
; ping!
; pong!
; ping!
; ... (5 rounds)
; Done!
```

## Example: Supervisor

```lisp
(define worker-behavior
  (behavior
    (initial-state 0)

    (receive 'work
      (lambda (ctx state)
        (print "Working...")
        (+ state 1)))

    (receive 'fail
      (lambda (ctx state)
        (error "Intentional failure!")))))

(define supervisor-behavior
  (supervisor
    (strategy 'one-for-one)
    (max-restarts 3)
    (within-ms 10000)
    (children
      (child 'worker-1 worker-behavior)
      (child 'worker-2 worker-behavior))))

(define sys (actor-system))
(define sup (spawn sys supervisor-behavior))

; Get refs to children
(define w1 (ask sup '(get-child worker-1)))
(define w2 (ask sup '(get-child worker-2)))

(send w1 'work)
(send w1 'fail)  ; w1 crashes and restarts
(send w1 'work)  ; continues working
```

## Integration with Existing Async

The `ask` primitive returns a Promise, integrating with existing async:

```lisp
; Sequential asks
(define v1 (ask actor1 'get))
(define v2 (ask actor2 'get))
; v1 and v2 are Promises

; Using with delay
(delay 1000 nil)  ; wait 1 second
(send actor 'delayed-message)

; Timeout on ask
(ask-timeout actor 'slow-operation 5000)  ; 5 second timeout
```

## Implementation Considerations

### 1. CEK Re-entry

When an actor receives a message, we need to run Lisp code (the handler). This means:
- The CEK machine is invoked from within actor message processing
- Multiple actors = multiple concurrent CEK evaluations
- Need to ensure Executor is shared appropriately

### 2. State Serialization

Actor state transitions through Lisp values:
- `initial-state` evaluated once at spawn
- Handler returns new state
- State must be convertible between Lisp values and Perl

### 3. Error Handling

When a handler throws:
- Actor should crash (Erlang philosophy)
- Supervisor decides: stop, restart, resume, escalate
- Error info should be preserved for debugging

### 4. Mailbox Integration

grey::static's Actor::Mailbox manages lifecycle:
- STARTING → ALIVE → RUNNING → STOPPED
- Need to map Lisp signal handlers to these states

## Future Extensions

1. **Actor discovery** - Registry for named actors
2. **Distributed actors** - Refs that work across processes
3. **Persistence** - Event sourcing for actor state
4. **Testing utilities** - TestProbe for actor testing
5. **Monitoring** - Death watch, actor introspection
6. **Routing** - Round-robin, broadcast, consistent-hashing routers

## Summary

Integrating actors into CEK Lisp provides:
- **True concurrency** via grey::static's actor runtime
- **Fault tolerance** via supervision trees
- **Natural async** via Promise-returning `ask`
- **Lisp-native syntax** via lambda-based behavior definitions
- **Hot code swapping** via `become-with`

The main implementation work is:
1. Creating the bridge between Lisp lambdas and grey::static Behaviors
2. Value type wrappers for ActorSystem, ActorRef, Context
3. Primitives for spawn, send, ask, reply, become, etc.
4. Pattern matching for receive clauses

This would make CEK Lisp a capable concurrent programming environment with Erlang-style actors and Lisp's expressiveness.
