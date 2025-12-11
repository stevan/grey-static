#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';
use grey::static qw[ concurrency::actor ];

# Test messages - must be at package level
class Ping :isa(Actor::Message) {}
class Pong :isa(Actor::Message) {}
class TestStarted {}

# Test actors with package-level tracking
our @CALLS;
our $PING_COUNT = 0;
our $PONG_COUNT = 0;
our $STARTED_COUNT = 0;

class PingPongActor :isa(Actor) {
    method on_ping :Receive(Ping) ($context, $message) {
        $main::PING_COUNT++;
    }

    method on_pong :Receive(Pong) ($context, $message) {
        $main::PONG_COUNT++;
    }
}

class SignalActor :isa(Actor) {
    method on_started :Signal(TestStarted) ($context, $signal) {
        $main::STARTED_COUNT++;
    }
}

class EmptyActor :isa(Actor) {}

class StatefulActor :isa(Actor) {
    method normal_ping :Receive(Ping) ($context, $message) {
        push @main::CALLS => 'normal';
    }
}

class StackActor :isa(Actor) {
    method default_ping :Receive(Ping) ($context, $message) {
        push @main::CALLS => 'default';
    }
}

subtest 'Actor with @Receive attribute' => sub {
    $PING_COUNT = 0;
    $PONG_COUNT = 0;

    my $actor = PingPongActor->new;
    ok($actor, '... actor created');

    # Dispatch messages directly via receive
    my $ping_handled = $actor->receive(undef, Ping->new);
    ok($ping_handled, '... Ping was handled');
    is($PING_COUNT, 1, '... on_ping was called');

    my $pong_handled = $actor->receive(undef, Pong->new);
    ok($pong_handled, '... Pong was handled');
    is($PONG_COUNT, 1, '... on_pong was called');
};

subtest 'Actor with @Signal attribute' => sub {
    $STARTED_COUNT = 0;

    my $actor = SignalActor->new;

    my $handled = $actor->signal(undef, TestStarted->new);
    ok($handled, '... signal was handled');
    is($STARTED_COUNT, 1, '... on_started was called');
};

subtest 'Actor unhandled message returns false' => sub {
    my $actor = EmptyActor->new;
    my $handled = $actor->receive(undef, Ping->new);
    ok(!$handled, '... unhandled message returns false');
};

subtest 'Actor become/unbecome' => sub {
    @CALLS = ();

    my $actor = StatefulActor->new;

    # Normal behavior
    $actor->receive(undef, Ping->new);
    is_deeply(\@CALLS, ['normal'], '... normal handler called');

    # Create alternate behavior
    my $alt_behavior = Actor::Behavior->new(
        receivers => {
            'Ping' => sub ($self, $ctx, $msg) { push @CALLS => 'alternate' },
        }
    );

    # Push alternate behavior
    $actor->become($alt_behavior);
    $actor->receive(undef, Ping->new);
    is_deeply(\@CALLS, ['normal', 'alternate'], '... alternate handler called');

    # Pop back to normal
    $actor->unbecome;
    $actor->receive(undef, Ping->new);
    is_deeply(\@CALLS, ['normal', 'alternate', 'normal'], '... back to normal handler');
};

subtest 'Actor behavior stack is LIFO' => sub {
    @CALLS = ();

    my $actor = StackActor->new;

    my $behavior_a = Actor::Behavior->new(
        receivers => { 'Ping' => sub ($self, $ctx, $msg) { push @CALLS => 'A' } }
    );
    my $behavior_b = Actor::Behavior->new(
        receivers => { 'Ping' => sub ($self, $ctx, $msg) { push @CALLS => 'B' } }
    );

    $actor->receive(undef, Ping->new);  # default
    $actor->become($behavior_a);
    $actor->receive(undef, Ping->new);  # A
    $actor->become($behavior_b);
    $actor->receive(undef, Ping->new);  # B
    $actor->unbecome;
    $actor->receive(undef, Ping->new);  # back to A
    $actor->unbecome;
    $actor->receive(undef, Ping->new);  # back to default

    is_deeply(\@CALLS, ['default', 'A', 'B', 'A', 'default'], '... LIFO behavior stack');
};

done_testing;
