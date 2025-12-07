
use v5.40;
use experimental qw[ class ];

class IO::Stream::Source::LinesFromHandle :isa(Stream::Source) {
    field $fh :param :reader;

    method next { scalar $fh->getline }

    method has_next { !$fh->eof }
}
