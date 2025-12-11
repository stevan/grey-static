#!perl

use v5.42;
use utf8;
use Test::More;

use grey::static qw[ tty::ansi tty::graphics ];

subtest '... test Graphics::Shader creation with TOP_LEFT coords' => sub {
    my $shader = Graphics::Shader->new(
        height => 10,
        width => 20,
        coord_system => Graphics::Shader->TOP_LEFT,
        shader => sub ($p, $t) {
            return Graphics::Color->new(r => 0, g => 0, b => 0);
        }
    );

    isa_ok($shader, 'Graphics::Shader');
    is($shader->rows, 9, '... height adjusted to odd number (10 -> 9)');
    is($shader->cols, 19, '... width adjusted to odd number (20 -> 19)');
};

subtest '... test Graphics::Shader creation with CENTERED coords' => sub {
    my $shader = Graphics::Shader->new(
        height => 11,
        width => 21,
        coord_system => Graphics::Shader->CENTERED,
        shader => sub ($p, $t) {
            return Graphics::Color->new(r => 0, g => 0, b => 0);
        }
    );

    isa_ok($shader, 'Graphics::Shader');
    is($shader->rows, 11, '... height already odd');
    is($shader->cols, 21, '... width already odd');
};

subtest '... test Graphics::Shader with odd dimensions' => sub {
    my $shader = Graphics::Shader->new(
        height => 15,
        width => 25,
        shader => sub ($p, $t) {
            return Graphics::Color->new(r => 1, g => 0, b => 0);
        }
    );

    is($shader->rows, 15, '... odd height unchanged');
    is($shader->cols, 25, '... odd width unchanged');
};

subtest '... test Graphics::Shader requires positive dimensions' => sub {
    eval {
        Graphics::Shader->new(
            height => 0,
            width => 20,
            shader => sub { }
        );
    };
    like($@, qr/height.*greater than 0/, '... height must be > 0');

    eval {
        Graphics::Shader->new(
            height => 20,
            width => 0,
            shader => sub { }
        );
    };
    like($@, qr/width.*greater than 0/, '... width must be > 0');
};

subtest '... test Graphics::Shader requires CODE ref' => sub {
    eval {
        Graphics::Shader->new(
            height => 20,
            width => 20,
            shader => "not a coderef"
        );
    };
    like($@, qr/shader.*CODE ref/, '... shader must be CODE ref');
};

subtest '... test Graphics::Shader with simple shader function' => sub {
    my $called = 0;
    my $last_point;
    my $last_time;

    my $shader = Graphics::Shader->new(
        height => 3,
        width => 3,
        shader => sub ($p, $t) {
            $called++;
            $last_point = $p;
            $last_time = $t;
            return Graphics::Color->new(r => 0.5, g => 0.5, b => 0.5);
        }
    );

    # Capture output (don't actually print to terminal)
    my $output;
    {
        local *STDOUT;
        open(STDOUT, '>', \$output) or die "Can't redirect STDOUT: $!";
        ANSI::set_output_to_utf8(\*STDOUT);
        $shader->draw(42);
    }

    ok($called > 0, '... shader function was called');
    isa_ok($last_point, 'Graphics::Point', '... shader received Point');
    is($last_time, 42, '... shader received time parameter');
};

subtest '... test Graphics::Shader coordinate system constants' => sub {
    is(Graphics::Shader->TOP_LEFT, 1, '... TOP_LEFT constant is 1');
    is(Graphics::Shader->CENTERED, 2, '... CENTERED constant is 2');
};

done_testing;
