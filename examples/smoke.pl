#!perl

use v5.40;
use experimental qw[ class ];

use Test::More;
use Test::Differences;

use Term::ReadKey qw[ GetTerminalSize ];

use Stream;
use Stream::Time;

my $strands = shift(@ARGV) // 5;

my ($WIDTH, $HEIGHT) = GetTerminalSize();

$HEIGHT = floor($HEIGHT * 0.9);
$WIDTH -= 4;

my @offsets = map { rand() * 0.02 } 1 .. $strands;

sub wave ($amp, $freq, $f, $p) { ($amp * $f->( 2 * 3.14 * $freq * $p )) }

sub combine (@waves) {
    my $v = 0;
    $v -= wave(@$_) foreach @waves;
    $v /= scalar @waves;
    return $v;
}

sub plot ($x, $t, @waves) {
    state $height = $HEIGHT * 0.5;
    my $wave = combine(
        [ 0.9, 15.0, \&CORE::sin, $x + ($t * 0.8) ],
        [ 0.6, 25.0, \&CORE::cos, $x + ($t * 1.2) ],
        [ 0.9, 35.0, \&CORE::sin, $x + ($t * 0.9) ],
        [ 0.3, 50.0, \&CORE::cos, $x + ($t * 1.6) ],
    );
    return int($height - int($wave * $height));
}

my $home_cursor  = "\e[H";
my $clear_screen = "\e[2J";

my $hide_cursor  = "\e[?25l";
my $show_cursor  = "\e[?25h";

my $enable_alt_buf  = "\e[?1049h";
my $disable_alt_buf = "\e[?1049l";

local $SIG{INT} = sub {
    print $show_cursor; #,$disable_alt_buf;
    die "\nInteruppted!";
};

print $clear_screen,$hide_cursor,$enable_alt_buf;

my $t = Stream::Time
->of_monotonic
->sleep_for(0.016)
->map(sub ($t) {
    join "\n" => map {
        my $row = $_;
        join '' => map {
            my $col = $_;
            my $out = ' ';
            foreach my ($i, $o) (indexed @offsets) {
                my $color = ($i + 2);
                my $at = plot($col, $t * $o );
                $out = "\e[38;5;${color}m▒\e[0m" if $at   == $row;
            }
            $out;
        } 0 .. $WIDTH;
    } 0 .. $HEIGHT;
})
->foreach(sub ($buffer) {
    print $home_cursor,$buffer;
});


done_testing;

__DATA__

