
use v5.40;
use experimental qw[ class ];

use importer 'Path::Tiny' => 'path';

use IO::Stream::Source::FilesFromDirectory;

class IO::Stream::Directories {
    sub files ($class, $dir, %opts) {

        $dir = path($dir) unless blessed $dir;

        Stream->new(
            source => IO::Stream::Source::FilesFromDirectory->new( dir => $dir, %opts )
        )
    }

    sub walk ($class, $dir, %opts) {

        __PACKAGE__->files( $dir, %opts )->recurse(
            sub ($c) { $c->is_dir },
            sub ($c) {
                IO::Stream::Source::FilesFromDirectory->new( dir => $c )
            }
        );
    }
}
