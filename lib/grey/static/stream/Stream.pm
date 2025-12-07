
use v5.40;
use experimental qw[ class defer ];

use Stream::Source;
use Stream::Source::FromArray;
use Stream::Source::FromArray::OfStreams;
use Stream::Source::FromIterator;
use Stream::Source::FromRange;
use Stream::Source::FromSupplier;

use Stream::Operation;
use Stream::Operation::Buffered;
use Stream::Operation::Collect;
use Stream::Operation::Every;
use Stream::Operation::FlatMap;
use Stream::Operation::Flatten;
use Stream::Operation::ForEach;
use Stream::Operation::Gather;
use Stream::Operation::Grep;
use Stream::Operation::Map;
use Stream::Operation::Match;
use Stream::Operation::Peek;
use Stream::Operation::Recurse;
use Stream::Operation::Reduce;
use Stream::Operation::Take;
use Stream::Operation::TakeUntil;
use Stream::Operation::When;

use Stream::Collectors;

use Stream::Match;
use Stream::Match::Builder;

class Stream {
    field $source :param :reader;
    field $prev   :param :reader = undef;

    field $on_open;
    field $on_close;

    ## -------------------------------------------------------------------------

    method is_head { not defined $prev }

    ## -------------------------------------------------------------------------

    method has_on_open  { defined $on_open  }
    method has_on_close { defined $on_close }

    method call_on_open  {
        $on_open ->accept( $self );
        return;
    }
    method call_on_close {
        $on_close->accept( $self );
        return;
    }

    method on_open  ($f) {
        $on_open = blessed $f ? $f : Consumer->new( f => $f );
        return $self;
    }
    method on_close ($f) {
        $on_close = blessed $f ? $f : Consumer->new( f => $f );
        return $self;
    }

    ## -------------------------------------------------------------------------
    ## Additional Constructors
    ## -------------------------------------------------------------------------

    # ->of( @list )
    # ->of( [ @list ] )
    sub of ($class, @list) {

        @list = $list[0]->@*
            if scalar @list == 1 && ref $list[0] eq 'ARRAY';
        $class->new(
            source => Stream::Source::FromArray->new( array => \@list )
        )
    }

    # Infinite Generator
    # ->generate(sub { ... })
    # ->generate(Supplier->new)
    sub generate ($class, $f) {

        $class->new(
            source => Stream::Source::FromSupplier->new(
                supplier => blessed $f ? $f : Supplier->new(
                    f => $f
                )
            )
        )
    }

    # Range iterator
    # ->range($start, $end)
    # ->range($start, $end, $step)
    sub range ($class, $start, $end, $step=1) {

        $class->new(
            source => Stream::Source::FromRange->new(
                start => $start,
                end   => $end,
                step  => $step,
            )
        )
    }

    # Infinite Iterator
    # ->iterate($seed, sub { ... })
    # ->iterate($seed, Function->new)
    # Finite Iterator
    # ->iterate($seed, sub { ... }, sub { ... })
    # ->iterate($seed, Predicate->new, Function->new)
    sub iterate ($class, $seed, @args) {

        my ($next, $has_next);

        if (scalar @args == 1) {
            $next = blessed $args[0] ? $args[0]
                    : Function->new( f => $args[0] );
        }
        else {
            $has_next = blessed $args[0] ? $args[0]
                      : Predicate->new( f => $args[0] );
            $next     = blessed $args[1] ? $args[1]
                      : Function->new( f => $args[1] );
        }

        $class->new(
            source => Stream::Source::FromIterator->new(
                seed     => $seed,
                next     => $next,
                has_next => $has_next,
            )
        )
    }

    sub concat ($class, @sources) {

        $class->new(
            source => Stream::Source::FromArray::OfStreams->new(
                sources => [ map $_->source, @sources ]
            )
        )
    }

    ## -------------------------------------------------------------------------
    ## Terminals
    ## -------------------------------------------------------------------------

    my sub execute ($self, $terminal) {

        my (@open, @close);

        my $s = $self;
        while (defined $s) {
            unshift @open  => $s if $s->has_on_open;
            push    @close => $s if $s->has_on_close;
            $s = $s->prev;
        }

        return $terminal->apply if !@open && !@close;

        $_->call_on_open foreach @open;
        return $terminal->apply if !@close;

        my @result = $terminal->apply;
        $_->call_on_close foreach @close;

        return wantarray ? @result : $result[0];
    }

    method reduce ($init, $f) {
        execute($self, Stream::Operation::Reduce->new(
                source  => $source,
                initial => $init,
                reducer => blessed $f ? $f : BiFunction->new(
                    f => $f
                )
            )
        )
    }

    method foreach ($f) {
        execute($self, Stream::Operation::ForEach->new(
                source   => $source,
                consumer => blessed $f ? $f : Consumer->new(
                    f => $f
                )
            )
        )
    }

    method collect ($acc) {
        execute($self, Stream::Operation::Collect->new(
                source      => $source,
                accumulator => $acc
            )
        )
    }

    method match ($matcher) {
        execute($self, Stream::Operation::Match->new(
                source  => $source,
                matcher => $matcher,
            )
        )
    }

    ## -------------------------------------------------------------------------
    ## Operations
    ## -------------------------------------------------------------------------

    method gather ($init, $reduce, $finish=undef) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Gather->new(
                source => $source,
                init   => blessed $init   ? $init   : Supplier->new( f => $init   ),
                reduce => blessed $reduce ? $reduce : BiFunction->new( f => $reduce ),
                ($finish ?
                    (finish => blessed $finish ? $finish : Function->new( f => $finish ))
                    : ()),
            )
        )
    }

    method flatten ($f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Flatten->new(
                source  => $source,
                flatten => blessed $f ? $f : Function->new(
                    f => $f
                )
            )
        )
    }

    method flat_map ($f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::FlatMap->new(
                source => $source,
                mapper => blessed $f ? $f : Function->new(
                    f => $f
                )
            )
        )
    }

    method flat_map_as ($stream_class, $f) {
        $stream_class->new(
            prev   => $self,
            source => Stream::Operation::FlatMap->new(
                source => $source,
                mapper => blessed $f ? $f : Function->new(
                    f => $f
                )
            )
        )
    }

    method recurse ($can_recurse, $recurse) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Recurse->new(
                source      => $source,
                can_recurse => blessed $can_recurse ? $can_recurse : Predicate->new( f => $can_recurse ),
                recurse     => blessed $recurse     ? $recurse     : Function ->new( f => $recurse ),
            )
        )
    }


    method every ($stride, $f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Every->new(
                source  => $source,
                stride  => $stride,
                event   => blessed $f ? $f : Consumer->new(
                    f => $f
                )
            )
        )
    }

    method take ($amount) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Take->new(
                source => $source,
                amount => $amount,
            )
        )
    }

    method take_until ($f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::TakeUntil->new(
                source    => $source,
                predicate => blessed $f ? $f : Predicate->new(
                    f => $f
                )
            )
        )
    }

    method when ($predicate, $f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::When->new(
                source    => $source,
                consumer  => blessed $f ? $f : Consumer->new(
                    f => $f
                ),
                predicate => blessed $predicate
                    ? $predicate
                    : Predicate->new( f => $predicate )
            )
        )
    }

    method map ($f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Map->new(
                source => $source,
                mapper => blessed $f ? $f : Function->new(
                    f => $f
                )
            )
        )
    }

    method grep ($f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Grep->new(
                source    => $source,
                predicate => blessed $f ? $f : Predicate->new(
                    f => $f
                )
            )
        )
    }

    method peek ($f) {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Peek->new(
                source   => $source,
                consumer => blessed $f ? $f : Consumer->new(
                    f => $f
                )
            )
        )
    }

    method buffered {
        __CLASS__->new(
            prev   => $self,
            source => Stream::Operation::Buffered->new( source => $source )
        )
    }

}
