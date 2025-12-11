# Actor System Guide

The `concurrency::actor` feature provides actor-based concurrency for grey::static, ported from the Yakt project.

## Quick Start

```perl
use grey::static qw[ concurrency::util concurrency::actor ];

# Define a simple actor
class Greeter :isa(Actor) {
    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Started) {
            say "Greeter started!";
            $ctx->stop;  # Stop after starting
        }
    }
}

# Run the actor system
ActorSystem->new->init(sub ($context) {
    $context->spawn(Actor::Props->new( class => 'Greeter' ));
})->loop_until_done;
```

## Core Concepts

### Actors

Actors are lightweight, isolated units of computation that:
- Process messages one at a time (no shared state)
- Can spawn child actors
- Have a lifecycle (started → running → stopped)
- Can be supervised for error handling

```perl
class MyActor :isa(Actor) {
    # Handle lifecycle signals
    method signal ($context, $signal) {
        if ($signal isa Actor::Signals::Started) {
            say "I'm alive!";
        }
    }

    # Handle messages
    method receive ($context, $message) {
        if ($message isa SomeMessage) {
            # Process the message
            return true;  # Message was handled
        }
        return false;  # Message not handled (goes to dead letters)
    }
}
```

### ActorSystem

The `ActorSystem` is the entry point and event loop:

```perl
my $sys = ActorSystem->new->init(sub ($context) {
    # This callback receives the //usr context
    # Spawn your actors here
    my $worker = $context->spawn(Actor::Props->new( class => 'Worker' ));
    $worker->send(DoWork->new);
});

$sys->loop_until_done;  # Blocks until all actors stop
```

### Actor::Props

Configuration for spawning actors:

```perl
my $props = Actor::Props->new(
    class      => 'MyActor',           # Required: actor class name
    args       => { foo => 'bar' },    # Optional: constructor arguments
    alias      => '//my/actor',        # Optional: lookup alias
    supervisor => Actor::Supervisors::Restart->new,  # Optional
);

my $ref = $context->spawn($props);
```

### Actor::Ref

A reference to an actor (its "address"):

```perl
my $ref = $context->spawn($props);
$ref->send(SomeMessage->new);  # Send a message
$ref->pid;                     # Get the process ID
```

### Actor::Context

The actor's interface to the system (passed to `signal` and `receive`):

```perl
method signal ($context, $signal) {
    $context->self;       # My own Ref
    $context->parent;     # Parent's Ref (or undef for root)
    $context->children;   # List of child Refs
    $context->props;      # Props used to create me

    # Spawn a child actor
    my $child = $context->spawn(Actor::Props->new(...));

    # Schedule a timer (returns Actor::Timer)
    my $timer = $context->schedule(
        after    => 2.5,      # seconds
        callback => sub { say "Timer fired!" }
    );
    $timer->cancel;  # Cancel if needed

    # Watch another actor for termination
    $context->watch($other_ref);

    # Stop this actor
    $context->stop;

    # Restart this actor
    $context->restart;
}
```

## Lifecycle Signals

Actors receive signals for lifecycle events:

| Signal | When |
|--------|------|
| `Actor::Signals::Started` | Actor initialized and ready |
| `Actor::Signals::Stopping` | Actor is shutting down |
| `Actor::Signals::Stopped` | Actor has stopped |
| `Actor::Signals::Terminated` | A watched/child actor stopped |
| `Actor::Signals::Ready` | Custom readiness notification |
| `Actor::Signals::Restarting` | Actor is restarting |

```perl
method signal ($context, $signal) {
    if ($signal isa Actor::Signals::Started) {
        say "Starting up...";
    }
    elsif ($signal isa Actor::Signals::Stopping) {
        say "Shutting down...";
    }
    elsif ($signal isa Actor::Signals::Terminated) {
        my $who = $signal->ref;
        my $error = $signal->with_error;  # undef if clean shutdown
        say "Actor $who terminated" . ($error ? " with error: $error" : "");
    }
}
```

## Messages

Define your own message classes:

```perl
class Ping :isa(Actor::Message) {
    field $reply_to :param :reader;
}

class Pong :isa(Actor::Message) {}

class PingActor :isa(Actor) {
    method receive ($ctx, $msg) {
        if ($msg isa Ping) {
            $msg->reply_to->send(Pong->new);
            return true;
        }
        return false;
    }
}
```

## Supervision

Supervisors handle errors in actors:

| Supervisor | Behavior |
|------------|----------|
| `Actor::Supervisors::Stop` | Stop the actor (default) |
| `Actor::Supervisors::Resume` | Skip the failed message, continue |
| `Actor::Supervisors::Retry` | Re-deliver the failed message |
| `Actor::Supervisors::Restart` | Restart the actor, re-deliver message |

```perl
my $props = Actor::Props->new(
    class      => 'UnreliableWorker',
    supervisor => Actor::Supervisors::Restart->new,
);
```

## Behavior Switching

Actors can change their behavior dynamically:

```perl
class StatefulActor :isa(Actor) {
    field $idle_behavior;
    field $busy_behavior;

    ADJUST {
        $idle_behavior = Actor::Behavior->new(
            receivers => {
                'StartWork' => sub ($self, $ctx, $msg) {
                    say "Starting work...";
                    $self->become($busy_behavior);
                }
            }
        );

        $busy_behavior = Actor::Behavior->new(
            receivers => {
                'WorkDone' => sub ($self, $ctx, $msg) {
                    say "Work done!";
                    $self->unbecome;  # Return to idle
                }
            }
        );
    }

    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Started) {
            $self->become($idle_behavior);
        }
    }
}
```

## Timer Scheduling

Schedule callbacks using the actor context:

```perl
method signal ($ctx, $sig) {
    if ($sig isa Actor::Signals::Started) {
        # One-shot timer
        $ctx->schedule(
            after    => 5.0,  # seconds
            callback => sub {
                say "5 seconds elapsed";
                $ctx->stop;
            }
        );
    }
}
```

## Actor Hierarchy

The system creates this hierarchy automatically:

```
// (root)
├── //sys
│   └── //sys/dead_letters
└── //usr
    └── (your actors here)
```

Actors spawned from the init callback become children of `//usr`.

## Important Notes

1. **Actors must stop themselves** - The system won't shut down while actors are alive. Call `$context->stop` when done.

2. **Single-threaded** - All actors run cooperatively in one thread. Don't block!

3. **Messages are processed one at a time** - No need for locks within an actor.

4. **Unhandled messages go to dead letters** - Return `true` from `receive` to indicate handling.

5. **Children stop before parents** - When an actor stops, all children stop first.

## Example: Ping-Pong

```perl
use grey::static qw[ concurrency::util concurrency::actor ];

class Ping :isa(Actor::Message) {
    field $count :param :reader;
}

class Pong :isa(Actor::Message) {
    field $count :param :reader;
}

class PingActor :isa(Actor) {
    field $pong_ref :param;
    field $remaining = 3;

    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Started) {
            $pong_ref->send(Ping->new( count => $remaining ));
        }
    }

    method receive ($ctx, $msg) {
        if ($msg isa Pong) {
            say "Ping got Pong #" . $msg->count;
            if (--$remaining > 0) {
                $pong_ref->send(Ping->new( count => $remaining ));
            } else {
                $ctx->stop;
            }
            return true;
        }
        return false;
    }
}

class PongActor :isa(Actor) {
    method receive ($ctx, $msg) {
        if ($msg isa Ping) {
            say "Pong got Ping #" . $msg->count;
            $msg->sender->send(Pong->new( count => $msg->count ));
            return true;
        }
        return false;
    }

    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Terminated) {
            $ctx->stop;  # Stop when ping stops
        }
    }
}

ActorSystem->new->init(sub ($ctx) {
    my $pong = $ctx->spawn(Actor::Props->new( class => 'PongActor' ));
    my $ping = $ctx->spawn(Actor::Props->new(
        class => 'PingActor',
        args  => { pong_ref => $pong }
    ));
    $ctx->watch($ping);  # Stop system when ping stops
})->loop_until_done;
```

## See Also

- `docs/yakt-integration-plan.md` - Full integration plan and API reference
- `/Users/stevan/Projects/perl/Yakt/` - Original Yakt project
- `t/grey/static/04-concurrency/actor/` - Test files with examples
