#!/usr/bin/env perl
use v5.42;
use experimental qw[ class ];

use lib 'lib';
use grey::static qw[ concurrency::util concurrency::actor ];

# Messages (using Actor::Message's built-in reply_to field)
class Ping :isa(Actor::Message) {
    field $count :param :reader;
}

class Pong :isa(Actor::Message) {
    field $count :param :reader;
}

# Pong actor - responds to Ping with Pong
class PongActor :isa(Actor) {
    method receive ($ctx, $msg) {
        if ($msg isa Ping) {
            say "  Pong received Ping #" . $msg->count;
            # Use the sender field from Actor::Message base class
            $msg->sender->send(Pong->new( count => $msg->count ));
            return true;
        }
        return false;
    }

    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Terminated) {
            say "  Pong: Ping actor terminated, stopping...";
            $ctx->stop;
        }
    }
}

# Ping actor - sends Pings, receives Pongs
class PingActor :isa(Actor) {
    field $pong_ref :param;
    field $rounds   :param = 5;

    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Started) {
            say "Ping starting with $rounds rounds";
            $self->send_ping($ctx, $rounds);
        }
    }

    method send_ping ($ctx, $n) {
        say "Ping sending #$n";
        $pong_ref->send(Ping->new(
            count  => $n,
            sender => $ctx->self  # Use sender field from Actor::Message
        ));
    }

    method receive ($ctx, $msg) {
        if ($msg isa Pong) {
            say "Ping received Pong #" . $msg->count;
            if ($msg->count > 1) {
                $self->send_ping($ctx, $msg->count - 1);
            } else {
                say "Ping done, stopping...";
                $ctx->stop;
            }
            return true;
        }
        return false;
    }
}

# Run the system
say "Starting Ping-Pong...";
say "";

ActorSystem->new->init(sub ($ctx) {
    # Spawn pong first
    my $pong = $ctx->spawn(Actor::Props->new( class => 'PongActor' ));

    # Spawn ping with reference to pong
    my $ping = $ctx->spawn(Actor::Props->new(
        class => 'PingActor',
        args  => { pong_ref => $pong, rounds => 3 }
    ));

    # Watch ping - when it stops, pong will get Terminated signal
    $pong->context->watch($ping);
})->loop_until_done;

say "";
say "All done!";
