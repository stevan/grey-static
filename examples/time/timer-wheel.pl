#!perl

use v5.42;
use utf8;
use experimental qw[ class builtin ];
use grey::static qw[ functional stream time::wheel tty::ansi ];

set_output_to_utf8();

use importer 'Data::Dumper' => qw[ Dumper ];
use importer 'Time::HiRes'  => qw[ sleep time ];

use Timer;
use Timer::Wheel;

my $w = Timer::Wheel->new;

my $max    = 999;
my $amount = $ARGV[0] // $max;

my @expected = map { 1+int(rand($max)) } 0 .. $amount;
my @got;
say "Testing $amount random timers ...";

{
    my $start = time;

    foreach my ($i, $t) (indexed @expected) {
        my $x = $t;
        $w->add_timer(Timer->new(
            id     => "timer$i",
            expiry => $t,
            event  => sub { push @got => $x }
        ));
    }
    say "Adding timers took :".(time - $start);
}

my $i = $max + 1;
while ($i--) {
    print "\e[2J\e[H";
    $w->advance_by( 1 );
    $w->dump_wheel;
    #my $x = <>;
    sleep(0.03);
}




