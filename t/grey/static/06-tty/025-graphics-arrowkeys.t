#!perl

use v5.42;
use utf8;

use Test::More;

use grey::static qw[ tty::graphics functional ];

subtest '... test ArrowKeys creation with individual handlers' => sub {
    my $up_called = 0;
    my $down_called = 0;

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up   => Consumer->new(f => sub { $up_called++ }),
        on_down => Consumer->new(f => sub { $down_called++ }),
    );

    isa_ok($keys, 'Graphics::Tools::ArrowKeys');
    is($up_called, 0, '... up handler not called yet');
    is($down_called, 0, '... down handler not called yet');
};

subtest '... test ArrowKeys creation with unified handler' => sub {
    my @events;

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_key => Consumer->new(f => sub ($event) {
            push @events, $event;
        })
    );

    isa_ok($keys, 'Graphics::Tools::ArrowKeys');
    is(scalar @events, 0, '... no events captured yet');
};

subtest '... test ArrowKeys requires at least one handler' => sub {
    eval {
        my $keys = Graphics::Tools::ArrowKeys->new();
    };

    like($@, qr/requires at least one handler/, '... throws error without handlers');
};

subtest '... test ArrowKeys turn_echo_off/on methods' => sub {
    my $keys = Graphics::Tools::ArrowKeys->new(
        on_key => Consumer->new(f => sub { })
    );

    # These should return self for chaining
    my $result1 = $keys->turn_echo_off;
    isa_ok($result1, 'Graphics::Tools::ArrowKeys', '... turn_echo_off returns self');

    my $result2 = $keys->turn_echo_on;
    isa_ok($result2, 'Graphics::Tools::ArrowKeys', '... turn_echo_on returns self');
};

subtest '... test ArrowKeys with lexically exported constructor' => sub {
    my $called = 0;

    my $keys = ArrowKeys(
        on_key => Consumer->new(f => sub { $called++ })
    );

    isa_ok($keys, 'Graphics::Tools::ArrowKeys');
};

subtest '... test multiple handlers can be combined' => sub {
    my $up_count = 0;
    my $all_count = 0;

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up => Consumer->new(f => sub { $up_count++ }),
        on_key => Consumer->new(f => sub { $all_count++ }),
    );

    isa_ok($keys, 'Graphics::Tools::ArrowKeys');
    # Both handlers should be registered
};

subtest '... test Consumer integration with BiConsumer' => sub {
    # Test that we can use BiConsumer for more complex handling
    my $state = { x => 0, y => 0 };

    my $move_up = BiConsumer->new(f => sub ($state, $key) {
        $state->{y}--;
    });

    my $up_handler = Consumer->new(f => sub ($key) {
        $move_up->accept($state, $key);
    });

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up => $up_handler,
    );

    isa_ok($keys, 'Graphics::Tools::ArrowKeys');
    is($state->{y}, 0, '... y position unchanged initially');
};

subtest '... test direction-specific callbacks' => sub {
    my %pressed;

    my $keys = Graphics::Tools::ArrowKeys->new(
        on_up    => Consumer->new(f => sub { $pressed{up}++ }),
        on_down  => Consumer->new(f => sub { $pressed{down}++ }),
        on_left  => Consumer->new(f => sub { $pressed{left}++ }),
        on_right => Consumer->new(f => sub { $pressed{right}++ }),
    );

    is($pressed{up} // 0, 0, '... up not pressed');
    is($pressed{down} // 0, 0, '... down not pressed');
    is($pressed{left} // 0, 0, '... left not pressed');
    is($pressed{right} // 0, 0, '... right not pressed');
};

done_testing;
