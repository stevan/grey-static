
use v5.42;
use experimental qw[ class ];

class Stream::Match {
    field $predicate :param :reader;

    field $next      :param = undef;
    field $skippable :param = false;
    field $on_match  :param = undef;

    field $was_skipped = false;

    method set_next ($n) { $next = $n }

    method has_next {
        # if we dont have a next, then we
        # can't have a next
        return false unless defined $next;
        # if we were skipped, we actually
        # need to check the next match in
        # the chain to know if we have
        # any more matches to go
        return $next->has_next if $was_skipped;
        # if we were not skipped and we
        # know we have a next, then we
        # can have a next
        return true;
    }

    method next {
        if ($was_skipped) {
            # if we were skipped, and this
            # next is retrieved, then we
            # no longer need to care about
            # having been skipped and can
            # reset this flag
            $was_skipped = false;
            # XXX - not sure if we should reset
            # the was_skipped flag or not, it
            # makes the matcher more re-usable
            # but do we really care?
            return $next->next;
        }
        return $next;
    }

    method match_found ($op) { $on_match ? $on_match->apply($op) : $op }

    method matches ($op) { $predicate->test($op) }

    method is_match ($op) {
        #say "??? Checking ".$op->name." for match";
        return true  if $self->matches($op);
        #say "??? Did not match immediate, looking for next";
        return false unless $next;
        #say "??? We have next checking if we are skippable";
        if ($skippable) {
            #say "!!! We are skippable, check if next matches";
            if ($next->is_match($op)) {
                #say ">>>>>>> Next matched!!!";
                # note that the match was skipped
                # so that we can pass the proper
                # next in the chain in next/has_next
                $was_skipped = true;
                return true;
            }
            #say "....... Next did NOT match!!!";
        }
        #say "Oh well, the match failed returning false";
        return false;
    }
}




