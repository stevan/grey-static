#!perl

use v5.42;
use experimental qw[ class ];

use Test::More;

use lib 'lib';
use grey::static qw[ concurrency::actor ];

# Define test message and signal classes
class TestMessage :isa(Actor::Message) {
    field $value :param :reader;
}

class TestSignal {
    field $type :param :reader;
}

# Simple actor for testing
class TestActor {
    field $received_message;
    field $received_signal;

    method handle_message ($ctx, $msg) {
        $received_message = $msg->value;
    }

    method handle_signal ($ctx, $sig) {
        $received_signal = $sig->type;
    }

    method received_message { $received_message }
    method received_signal  { $received_signal  }
}

subtest 'Actor::Behavior construction' => sub {
    my $behavior = Actor::Behavior->new;
    ok($behavior, '... behavior created');
    is_deeply($behavior->receivers, {}, '... empty receivers by default');
    is_deeply($behavior->handlers, {}, '... empty handlers by default');
};

subtest 'Actor::Behavior with receivers' => sub {
    my $actor = TestActor->new;

    my $behavior = Actor::Behavior->new(
        receivers => {
            'TestMessage' => \&TestActor::handle_message,
        }
    );

    my $msg = TestMessage->new(value => 42);

    # Dispatch the message
    my $handled = $behavior->receive_message($actor, undef, $msg);
    ok($handled, '... message was handled');
    is($actor->received_message, 42, '... handler received correct value');
};

subtest 'Actor::Behavior with handlers' => sub {
    my $actor = TestActor->new;

    my $behavior = Actor::Behavior->new(
        handlers => {
            'TestSignal' => \&TestActor::handle_signal,
        }
    );

    my $sig = TestSignal->new(type => 'started');

    # Dispatch the signal
    my $handled = $behavior->receive_signal($actor, undef, $sig);
    ok($handled, '... signal was handled');
    is($actor->received_signal, 'started', '... handler received correct signal');
};

subtest 'Actor::Behavior unhandled message returns false' => sub {
    my $actor = TestActor->new;
    my $behavior = Actor::Behavior->new;  # No receivers

    my $msg = TestMessage->new(value => 99);

    my $handled = $behavior->receive_message($actor, undef, $msg);
    ok(!$handled, '... unhandled message returns false');
};

subtest 'Actor::Behavior unhandled signal returns false' => sub {
    my $actor = TestActor->new;
    my $behavior = Actor::Behavior->new;  # No handlers

    my $sig = TestSignal->new(type => 'unknown');

    my $handled = $behavior->receive_signal($actor, undef, $sig);
    ok(!$handled, '... unhandled signal returns false');
};

done_testing;
