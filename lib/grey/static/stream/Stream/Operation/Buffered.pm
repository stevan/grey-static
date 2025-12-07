
use v5.40;
use experimental qw[ class ];

class Stream::Operation::Buffered :isa(Stream::Operation::Node) {
    field $source :param;

    field @buffer    :reader;
    field $buffering :reader = false;

    field @replay;

    method start_buffering { $buffering = true  }
    method stop_buffering  { $buffering = false }

    method clear_buffer { @buffer = () }
    method flush_buffer {
        my @temp = @buffer;
        $self->clear_buffer;
        return @temp;
    }

    method rewind { @replay = $self->flush_buffer }

    method next {
        return shift @replay if @replay;

        my $val = $source->next;
        push @buffer => $val if $buffering;
        return $val;
    }

    method has_next {
        @replay || $source->has_next
    }
}
