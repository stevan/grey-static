#!/usr/bin/env perl
use v5.42;
use experimental qw[ class ];

use lib 'lib';
use grey::static qw[ concurrency::util concurrency::actor ];

# A simple greeting message
class Greet :isa(Actor::Message) {
    field $name :param :reader;
}

# An actor that greets and then stops
class Greeter :isa(Actor) {
    method receive ($ctx, $msg) {
        if ($msg isa Greet) {
            say "Hello, " . $msg->name . "!";
            $ctx->stop;
            return true;
        }
        return false;
    }
}

# Run the actor system
ActorSystem->new->init(sub ($ctx) {
    my $greeter = $ctx->spawn(Actor::Props->new( class => 'Greeter' ));
    $greeter->send(Greet->new( name => 'World' ));
})->loop_until_done;

say "Done!";
