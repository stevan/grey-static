
use v5.42;
use experimental qw[ class ];

use B ();

use MOP::Glob;

class MOP::Source::GlobsFromStash :isa(Stream::Source) {
    field $stash :param :reader;

    field @globs;
    ADJUST {
        @globs = map  {
            # occasionally we need to auto-inflate
            # the optimized version of a required
            # method, its annoying.
            B::svref_2object( $stash )->NAME->can( $_ )
                if $stash->{$_} eq "-1" || ref $stash->{$_} ne 'GLOB';
            # safe to grab the glob now
            $stash->{$_};
        } sort { $a cmp $b } keys $stash->%*;
    }

    method     next { MOP::Glob->new( glob => \(shift @globs) ) }
    method has_next { !! scalar @globs }
}
