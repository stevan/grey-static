#!/usr/bin/env perl
use v5.42;
use experimental qw[ class ];

use lib 'lib';
use grey::static qw[ concurrency::util concurrency::actor ];

# An actor that uses timers
class TimerActor :isa(Actor) {
    field $ticks = 0;
    field $max_ticks :param = 5;

    method signal ($ctx, $sig) {
        if ($sig isa Actor::Signals::Started) {
            say "TimerActor started, will tick $max_ticks times";
            $self->schedule_tick($ctx);
        }
        elsif ($sig isa Actor::Signals::Stopping) {
            say "TimerActor stopping after $ticks ticks";
        }
    }

    method schedule_tick ($ctx) {
        $ctx->schedule(
            after    => 0.5,  # 500ms
            callback => sub {
                $ticks++;
                say "  Tick #$ticks";

                if ($ticks >= $max_ticks) {
                    say "Reached max ticks, stopping...";
                    $ctx->stop;
                } else {
                    $self->schedule_tick($ctx);
                }
            }
        );
    }
}

say "Starting timer example...";
say "";

ActorSystem->new->init(sub ($ctx) {
    $ctx->spawn(Actor::Props->new(
        class => 'TimerActor',
        args  => { max_ticks => 5 }
    ));
})->loop_until_done;

say "";
say "Done!";
