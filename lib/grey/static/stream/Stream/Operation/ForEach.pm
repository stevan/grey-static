
use v5.42;
use experimental qw[ class ];

class Stream::Operation::ForEach :isa(Stream::Operation::Terminal) {
    field $source   :param;
    field $consumer :param;

    method apply {

        while ($source->has_next) {
            $consumer->accept($source->next);
        }
        return;
    }
}
