
use v5.42;
use experimental qw[ class ];

class IO::Stream::Source::LinesFromHandle :isa(Stream::Source) {
    field $fh :param :reader;

    method next { scalar $fh->getline }

    method has_next { !$fh->eof }
}
