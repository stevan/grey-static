# Prompt: Actor IO Integration (Phase 4)

Use this prompt to continue the Yakt integration by porting the async IO selector system.

---

## Context

I've integrated the Yakt actor system into grey::static as `concurrency::actor`. The core is complete:
- Actor, ActorSystem, Props, Ref, Context, Behavior, Message
- Mailbox lifecycle state machine
- Signals (Started, Stopping, Stopped, Terminated, Ready, Restarting)
- Supervisors (Stop, Resume, Retry, Restart)
- Timer scheduling via ScheduledExecutor

See `docs/yakt-integration-plan.md` for the full plan.

## Task: Implement Phase 4 - IO Integration

Port Yakt's async IO selector system to enable non-blocking network and file IO.

### Source Files (Yakt)

```
/Users/stevan/Projects/perl/Yakt/lib/Yakt/System/IO.pm           # IO Manager
/Users/stevan/Projects/perl/Yakt/lib/Yakt/System/IO/Selector.pm  # Base selector
/Users/stevan/Projects/perl/Yakt/lib/Yakt/System/IO/Selector/Socket.pm
/Users/stevan/Projects/perl/Yakt/lib/Yakt/System/IO/Selector/Stream.pm
/Users/stevan/Projects/perl/Yakt/lib/Yakt/System/IO/Signals.pm   # IO signals
```

### Target Structure

Create `lib/grey/static/concurrency/io/`:

```
lib/grey/static/concurrency/io/
├── Manager.pm              # IO manager (from Yakt::System::IO)
├── Selector.pm             # Base selector class
└── Selector/
    ├── Socket.pm           # TCP/UDP sockets
    └── Stream.pm           # File handles, pipes
```

Create IO signals in `lib/grey/static/concurrency/actor/Actor/Signals/IO/`:

```
lib/grey/static/concurrency/actor/Actor/Signals/IO/
├── CanRead.pm
├── CanWrite.pm
├── IsConnected.pm
├── GotError.pm
└── CanAccept.pm
```

### Classes to Port

#### 1. IO::Selector (base class)

```perl
class IO::Selector {
    field $ref :param :reader;  # Actor ref to notify
    field $fh  :param :reader;  # File handle
}
```

#### 2. IO::Selector::Socket

For TCP/UDP sockets. Signals:
- `CanRead` - Data available to read
- `CanWrite` - Ready to write
- `IsConnected` - Connection established
- `GotError` - Error occurred
- `CanAccept` - Server socket has pending connection

#### 3. IO::Selector::Stream

For file handles and pipes. Signals:
- `CanRead` - Data available
- `CanWrite` - Ready to write

#### 4. IO::Manager

Manages selectors and dispatches signals:

```perl
class IO::Manager {
    field @readers;
    field @writers;

    method add_selector ($selector) { ... }
    method remove_selector ($selector) { ... }
    method has_active_selectors { ... }

    method tick ($timeout) {
        # Use IO::Select to poll
        my ($r, $w, $e) = IO::Select::select(
            $readers_select, $writers_select, $error_select, $timeout
        );
        # Dispatch signals to actors
    }
}
```

### Integration Points

1. **ActorSystem** - Add IO manager field and integrate with event loop:

```perl
# In ActorSystem
field $io;

ADJUST {
    $io = IO::Manager->new;
}

method io { $io }

method tick {
    $executor->tick;
    $self->run_mailboxes;
    $io->tick($self->should_wait_time);  # Add this
}

method loop_until_done {
    # ...
    next if $executor->has_active_timers
         || $io->has_active_selectors;  # Add this
    # ...
}
```

2. **Actor::Context** - Add `add_selector` method:

```perl
method add_selector ($selector) {
    $system->io->add_selector($selector);
}
```

### Feature Loader

Create new subfeature `concurrency::io`:

```perl
elsif ($subfeature eq 'io') {
    use lib File::Basename::dirname(__FILE__) . '/concurrency/io';
    load_module('IO::Selector');
    load_module('IO::Selector::Socket');
    load_module('IO::Selector::Stream');
    load_module('IO::Manager');

    # Also load IO signals into actor namespace
    use lib File::Basename::dirname(__FILE__) . '/concurrency/actor';
    load_module('Actor::Signals::IO::CanRead');
    load_module('Actor::Signals::IO::CanWrite');
    load_module('Actor::Signals::IO::IsConnected');
    load_module('Actor::Signals::IO::GotError');
    load_module('Actor::Signals::IO::CanAccept');
}
```

### Tests to Create

Create tests in `t/grey/static/04-concurrency/io/`:
- `050-selector.t` - Base selector tests
- `051-socket.t` - Socket selector tests (may need echo server)
- `052-stream.t` - Stream selector tests (pipes, files)

### Example Usage

```perl
use grey::static qw[ concurrency::actor concurrency::io ];

class EchoServer :isa(Actor) {
    field $server_socket;

    method on_started :Signal(Actor::Signals::Started) ($ctx, $sig) {
        $server_socket = IO::Socket::INET->new(
            LocalPort => 8080,
            Listen    => 5,
            Reuse     => 1,
        );

        $ctx->add_selector(IO::Selector::Socket->new(
            ref => $ctx->self,
            fh  => $server_socket,
        ));
    }

    method on_can_accept :Signal(Actor::Signals::IO::CanAccept) ($ctx, $sig) {
        my $client = $server_socket->accept;
        # Handle client...
    }
}
```

---

## Reference Files

- Integration plan: `docs/yakt-integration-plan.md` (Phase 4 section)
- Yakt IO: `/Users/stevan/Projects/perl/Yakt/lib/Yakt/System/IO.pm`
- Yakt IO tests: `/Users/stevan/Projects/perl/Yakt/t/010-io/`
- ActorSystem: `lib/grey/static/concurrency/actor/ActorSystem.pm`

## Notes

- This is the trickiest part of the integration due to IO::Select complexity
- Consider starting with Stream selectors (simpler) before Socket
- May need to handle edge cases around selector lifecycle (add/remove during tick)
- Test with real IO operations (pipes work well for tests)
