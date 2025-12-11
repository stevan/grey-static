# Prompt: Actor Bridge Classes (Phase 5)

Use this prompt to continue the Yakt integration by implementing bridge classes between Actors, Flow, and Promises.

---

## Context

I've integrated the Yakt actor system into grey::static as `concurrency::actor`. The core is complete:
- Actor, ActorSystem, Props, Ref, Context, Behavior, Message
- Mailbox lifecycle state machine
- Signals (Started, Stopping, Stopped, Terminated, Ready, Restarting)
- Supervisors (Stop, Resume, Retry, Restart)
- Timer scheduling via ScheduledExecutor

See `docs/yakt-integration-plan.md` for the full plan.

## Task: Implement Phase 5 - Bridge Classes

Create interop classes between Actors, Flow (reactive streams), and Promises.

### 1. Actor → Flow Bridge: ActorPublisher

Create `lib/grey/static/concurrency/actor/Actor/Flow/ActorPublisher.pm`

An actor that publishes messages to a Flow pipeline:

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

### 2. Flow → Actor Bridge: FlowSubscriberActor

Create an actor that subscribes to a Flow and processes items:

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

### 3. Promise-based Ask Pattern: Actor::Ask

Implement request-response with Promises:

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

        return $promise;  # Could add timeout support
    }
}
```

### 4. Supervised Flow Pipeline

Create an actor that supervises a Flow pipeline:

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

### Tests to Create

Create tests in `t/grey/static/04-concurrency/actor/bridge/`:
- `060-actor-flow.t` - ActorPublisher tests
- `061-actor-promise.t` - Ask pattern tests
- `062-supervised-flow.t` - SupervisedPipeline tests

### Update Feature Loader

Add bridge classes to `lib/grey/static/concurrency.pm` under the `actor` subfeature.

### Documentation

Update `docs/concurrency-actor-guide.md` with bridge class usage examples.

---

## Reference Files

- Integration plan: `docs/yakt-integration-plan.md` (Phase 5 section)
- Actor implementation: `lib/grey/static/concurrency/actor/`
- Flow implementation: `lib/grey/static/concurrency/reactive/`
- Promise implementation: `lib/grey/static/concurrency/util/Promise.pm`
- Existing actor tests: `t/grey/static/04-concurrency/actor/`
