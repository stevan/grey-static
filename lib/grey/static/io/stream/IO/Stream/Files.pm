
use v5.40;
use experimental qw[ class ];

use importer 'Path::Tiny' => 'path';

use IO::Stream::Source::BytesFromHandle;
use IO::Stream::Source::LinesFromHandle;

class IO::Stream::Files {
    sub bytes ($class, $fh, %opts) {

        $fh = path($fh)->openr unless blessed $fh || ref $fh eq 'GLOB';

        Stream->new(
            source => IO::Stream::Source::BytesFromHandle->new( fh => $fh, %opts ),
        )
    }

    sub lines ($class, $fh, %opts) {

        $fh = path($fh)->openr unless blessed $fh || ref $fh eq 'GLOB';

        Stream->new(
            source => IO::Stream::Source::LinesFromHandle->new( fh => $fh, %opts )
        )
    }
}
