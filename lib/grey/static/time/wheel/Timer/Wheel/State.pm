
use v5.42;
use experimental qw[ class ];

use importer 'Data::Dumper' => qw[ Dumper ];
use importer 'List::Util'   => qw[ mesh ];

class Timer::Wheel::State {
    use constant DEBUG => $ENV{DEBUG} // 0;

    use overload '""' => \&to_string;
    field $num_gears :param :reader;

    field $time    :reader =  0;
    field @gears   :reader = (0) x $num_gears;
    field @changes :reader = (0) x $num_gears;

    method advance {
        $time++;

        @changes = (0) x $num_gears;

        my $i = 0;
        DEBUG && say "i($i) num_gears($num_gears) @ time($time)";
        while ($i < $num_gears) {
            DEBUG && say ".. i($i) num_gears($num_gears) @ time($time)";
            DEBUG && say "gears[$i] = ",$gears[$i];
            if ($gears[$i] < 9) {
                $gears[$i]++;
                DEBUG && say "inc gears[$i] = ",$gears[$i];
                $changes[$i] = $gears[$i];
                last;
            } else {
                DEBUG && say "... rolled over i($i) to zero @ time($time)";
                $gears[$i] = 0;
                $i++;
            }
        }
    }

    method to_string {
        sprintf 'State[%s](%d)' => (join ':', @gears), $time;
    }
}
