package ANSI;

use v5.38;
use experimental qw[ builtin ];
use builtin      qw[ export_lexically ];

use ANSI::Screen ();
use ANSI::Color  ();
use ANSI::Cursor ();
use ANSI::Mouse  ();

use Term::ReadKey qw[ GetTerminalSize ReadMode ];

sub import {
    my $to = caller;
    $to->ANSI::Screen::import;
    $to->ANSI::Color::import;
    $to->ANSI::Cursor::import;
    $to->ANSI::Mouse::import;

    export_lexically(
        '&get_terminal_size'       => \&get_terminal_size,

        '&restore_read_mode'       => \&restore_read_mode,
        '&set_read_mode_to_normal' => \&set_read_mode_to_normal,
        '&set_read_mode_to_noecho' => \&set_read_mode_to_noecho,
        '&set_read_mode_to_raw'    => \&set_read_mode_to_raw,

        '&set_output_to_utf8'      => \&set_output_to_utf8,
    );
}


sub get_terminal_size { GetTerminalSize() }

sub set_output_to_utf8 ($fh=*STDOUT) { binmode($fh, ":encoding(UTF-8)") }

sub restore_read_mode       ($fh=*STDIN) { ReadMode restore => $fh }
sub set_read_mode_to_normal ($fh=*STDIN) { ReadMode normal  => $fh }
sub set_read_mode_to_noecho ($fh=*STDIN) { ReadMode noecho  => $fh }
sub set_read_mode_to_raw    ($fh=*STDIN) { ReadMode cbreak  => $fh }



__END__
