#!/usr/bin/env perl
use v5.42;
use experimental qw[ class ];

use lib '../../lib';
use grey::static qw[ concurrency::util ];

# =============================================================================
# CEK Machine Mini-Lisp
# =============================================================================
# A small Lisp interpreter using the CEK abstract machine model.
# - C (Control): The expression being evaluated, or a value
# - E (Environment): Current variable bindings
# - K (Kontinuation): What to do with the result
#
# Key insight: Continuations are data structures, not implicit in the call stack.
# This enables call/cc, async primitives, and step-by-step debugging.
# =============================================================================

# =============================================================================
# VALUES
# =============================================================================

class NumVal {
    field $n :param :reader;
    method is_truthy { $n != 0 }
    method type { 'num' }
}

class SymVal {
    field $s :param :reader;
    method is_truthy { 1 }
    method type { 'sym' }
}

class ConsVal {
    field $car :param :reader;
    field $cdr :param :reader;
    method is_truthy { 1 }
    method type { 'cons' }
}

class NilVal {
    method is_truthy { 0 }
    method type { 'nil' }
}

class LambdaVal {
    field $params :param :reader;
    field $body   :param :reader;
    field $env    :param :reader;
    method is_truthy { 1 }
    method type { 'lambda' }
}

class PrimVal {
    field $name :param :reader;
    field $impl :param :reader;  # sub ($args, $env, $kont) -> Value or Promise<Value>
    method is_truthy { 1 }
    method type { 'primitive' }
}

class ContVal {
    field $kont :param :reader;  # captured continuation for call/cc
    method is_truthy { 1 }
    method type { 'continuation' }
}

# Singleton nil
my $NIL = NilVal->new;
sub NIL() { $NIL }

# =============================================================================
# EXPRESSIONS (AST)
# =============================================================================

class NumExpr {
    field $value :param :reader;
    method is_expr { 1 }
    method type { 'num' }
}

class SymExpr {
    field $name :param :reader;
    method is_expr { 1 }
    method type { 'sym' }
}

class IfExpr {
    field $test :param :reader;
    field $then :param :reader;
    field $else :param :reader;
    method is_expr { 1 }
    method type { 'if' }
}

class LamExpr {
    field $params :param :reader;
    field $body   :param :reader;
    method is_expr { 1 }
    method type { 'lambda' }
}

class AppExpr {
    field $fn   :param :reader;
    field $args :param :reader;
    method is_expr { 1 }
    method type { 'app' }
}

class QuoteExpr {
    field $datum :param :reader;
    method is_expr { 1 }
    method type { 'quote' }
}

# =============================================================================
# KONTINUATIONS
# =============================================================================

class HaltK {
    method type { 'halt' }
}

class IfK {
    field $then :param :reader;
    field $else :param :reader;
    field $env  :param :reader;
    field $k    :param :reader;
    method type { 'if' }
}

class FnK {
    field $args :param :reader;  # argument expressions still to evaluate
    field $env  :param :reader;
    field $k    :param :reader;
    method type { 'fn' }
}

class ArgK {
    field $fn   :param :reader;  # the function value
    field $done :param :reader;  # evaluated argument values
    field $todo :param :reader;  # argument expressions still to evaluate
    field $env  :param :reader;
    field $k    :param :reader;
    method type { 'arg' }
}

# Singleton halt
my $HALT = HaltK->new;
sub HALT() { $HALT }

# =============================================================================
# ENVIRONMENT
# =============================================================================

class Env {
    field $bindings :param = {};
    field $parent   :param = undef;

    method lookup($name) {
        return $bindings->{$name} if exists $bindings->{$name};
        return $parent->lookup($name) if $parent;
        die "unbound variable: $name";
    }

    method extend($names, $values) {
        my %new;
        @new{@$names} = @$values;
        return Env->new(bindings => \%new, parent => $self);
    }

    method define($name, $value) {
        $bindings->{$name} = $value;
    }
}

# =============================================================================
# STATE
# =============================================================================

class State {
    field $control :param :reader;
    field $env     :param :reader;
    field $kont    :param :reader;

    method is_done {
        $kont isa HaltK && !($control->can('is_expr') && $control->is_expr);
    }

    method value { $control }

    method with_control($new_control) {
        State->new(control => $new_control, env => $env, kont => $kont);
    }

    method with_kont($new_kont) {
        State->new(control => $control, env => $env, kont => $new_kont);
    }

    method with_env($new_env) {
        State->new(control => $control, env => $new_env, kont => $kont);
    }
}

# =============================================================================
# CEK MACHINE
# =============================================================================

class CEK {
    field $executor :param;
    field $trace    :param = 0;  # enable step tracing

    method set_trace($val) { $trace = $val; }
    method toggle_trace { $trace = !$trace; return $trace; }

    # -------------------------------------------------------------------------
    # STEP DISPATCH
    # -------------------------------------------------------------------------

    method step($state) {
        my $control = $state->control;

        if ($control->can('is_expr') && $control->is_expr) {
            return $self->step_expr($control, $state->env, $state->kont);
        }
        return $self->step_kont($control, $state->env, $state->kont);
    }

    # -------------------------------------------------------------------------
    # STEP EXPRESSION
    # -------------------------------------------------------------------------

    method step_expr($expr, $env, $kont) {
        my $type = $expr->type;

        if ($type eq 'num') {
            return State->new(
                control => NumVal->new(n => $expr->value),
                env     => $env,
                kont    => $kont
            );
        }

        if ($type eq 'sym') {
            my $val = $env->lookup($expr->name);
            return State->new(control => $val, env => $env, kont => $kont);
        }

        if ($type eq 'quote') {
            my $val = $self->expr_to_value($expr->datum);
            return State->new(control => $val, env => $env, kont => $kont);
        }

        if ($type eq 'if') {
            my $new_kont = IfK->new(
                then => $expr->then,
                else => $expr->else,
                env  => $env,
                k    => $kont
            );
            return State->new(control => $expr->test, env => $env, kont => $new_kont);
        }

        if ($type eq 'lambda') {
            my $closure = LambdaVal->new(
                params => $expr->params,
                body   => $expr->body,
                env    => $env
            );
            return State->new(control => $closure, env => $env, kont => $kont);
        }

        if ($type eq 'app') {
            my $new_kont = FnK->new(
                args => $expr->args,
                env  => $env,
                k    => $kont
            );
            return State->new(control => $expr->fn, env => $env, kont => $new_kont);
        }

        die "unknown expression type: $type";
    }

    # -------------------------------------------------------------------------
    # STEP KONTINUATION
    # -------------------------------------------------------------------------

    method step_kont($value, $env, $kont) {
        my $type = $kont->type;

        if ($type eq 'halt') {
            # We're done - this shouldn't be called, but handle it
            return State->new(control => $value, env => $env, kont => $kont);
        }

        if ($type eq 'if') {
            my $branch = $value->is_truthy ? $kont->then : $kont->else;
            return State->new(control => $branch, env => $kont->env, kont => $kont->k);
        }

        if ($type eq 'fn') {
            my $args = $kont->args;
            if (@$args == 0) {
                # No arguments - apply immediately
                return $self->apply_fn($value, [], $kont->env, $kont->k);
            }
            # Start evaluating arguments
            my $new_kont = ArgK->new(
                fn   => $value,
                done => [],
                todo => [ @$args[1 .. $#$args] ],
                env  => $kont->env,
                k    => $kont->k
            );
            return State->new(control => $args->[0], env => $kont->env, kont => $new_kont);
        }

        if ($type eq 'arg') {
            my @done = (@{$kont->done}, $value);
            my $todo = $kont->todo;

            if (@$todo == 0) {
                # All args evaluated - apply
                return $self->apply_fn($kont->fn, \@done, $kont->env, $kont->k);
            }

            # More args to evaluate
            my $new_kont = ArgK->new(
                fn   => $kont->fn,
                done => \@done,
                todo => [ @$todo[1 .. $#$todo] ],
                env  => $kont->env,
                k    => $kont->k
            );
            return State->new(control => $todo->[0], env => $kont->env, kont => $new_kont);
        }

        die "unknown kontinuation type: $type";
    }

    # -------------------------------------------------------------------------
    # FUNCTION APPLICATION
    # -------------------------------------------------------------------------

    method apply_fn($fn, $args, $env, $kont) {
        my $type = $fn->type;

        if ($type eq 'lambda') {
            my $params = $fn->params;
            if (@$args != @$params) {
                die "arity mismatch: expected " . scalar(@$params) . ", got " . scalar(@$args);
            }
            my $new_env = $fn->env->extend($params, $args);
            return State->new(control => $fn->body, env => $new_env, kont => $kont);
        }

        if ($type eq 'primitive') {
            # Special handling for call/cc
            if ($fn->name eq 'call/cc') {
                my $proc = $args->[0];
                die "call/cc: argument must be a procedure"
                    unless $proc->type eq 'lambda' || $proc->type eq 'primitive';

                # Reify the current continuation as a value
                my $cont = ContVal->new(kont => $kont);

                # Apply the procedure to the reified continuation
                return $self->apply_fn($proc, [$cont], $env, $kont);
            }

            # Normal primitives can return Value or Promise<Value>
            my $result = $fn->impl->($args, $env, $kont);

            if ($result isa Promise) {
                # Async primitive - return Promise<State>
                return $result->then(sub ($val) {
                    return State->new(control => $val, env => $env, kont => $kont);
                });
            }

            # Sync primitive
            return State->new(control => $result, env => $env, kont => $kont);
        }

        if ($type eq 'continuation') {
            # call/cc: invoke captured continuation
            if (@$args != 1) {
                die "continuation expects 1 argument";
            }
            return State->new(control => $args->[0], env => $env, kont => $fn->kont);
        }

        die "not a function: $type";
    }

    # -------------------------------------------------------------------------
    # DRIVER (TRAMPOLINE)
    # -------------------------------------------------------------------------

    method run($expr, $env) {
        my $promise = Promise->new(executor => $executor);
        my $state = State->new(control => $expr, env => $env, kont => HaltK->new);

        $self->trampoline($state, $promise, 0);

        $executor->run;
        return $promise;
    }

    method trampoline($state, $final, $step_count) {
        $executor->next_tick(sub {
            if ($trace) {
                say "step $step_count: " . $self->format_state($state);
            }

            if ($state->is_done) {
                $final->resolve($state->value);
                return;
            }

            my $result;
            eval {
                $result = $self->step($state);
            };
            if ($@) {
                $final->reject($@);
                return;
            }

            if ($result isa Promise) {
                # Async step
                $result->then(
                    sub ($next_state) {
                        $self->trampoline($next_state, $final, $step_count + 1);
                    },
                    sub ($error) {
                        $final->reject($error);
                    }
                );
            } else {
                # Sync step
                $self->trampoline($result, $final, $step_count + 1);
            }
        });
    }

    # -------------------------------------------------------------------------
    # HELPERS
    # -------------------------------------------------------------------------

    method expr_to_value($expr) {
        # Handle both objects (with type method) and hashrefs (with type key)
        my $type;
        if (ref($expr) eq 'HASH') {
            $type = $expr->{type};
        } elsif ($expr->can('type')) {
            $type = $expr->type;
        } else {
            die "cannot quote: unknown expr type";
        }

        # Objects with methods
        if ($type eq 'num') {
            my $val = ref($expr) eq 'HASH' ? $expr->{value} : $expr->value;
            return NumVal->new(n => $val);
        }
        if ($type eq 'sym') {
            my $name = ref($expr) eq 'HASH' ? $expr->{name} : $expr->name;
            return SymVal->new(s => $name);
        }
        if ($type eq 'quote') {
            my $datum = ref($expr) eq 'HASH' ? $expr->{datum} : $expr->datum;
            return $self->expr_to_value($datum);
        }
        if ($type eq 'nil') {
            return NilVal->new;
        }
        if ($type eq 'list') {
            my $elements = ref($expr) eq 'HASH' ? $expr->{elements} : $expr->elements;
            return $self->list_to_cons($elements);
        }
        die "cannot quote: $type";
    }

    method list_to_cons($elements) {
        my $result = NilVal->new;
        for my $elem (reverse @$elements) {
            $result = ConsVal->new(
                car => $self->expr_to_value($elem),
                cdr => $result
            );
        }
        return $result;
    }

    method format_state($state) {
        my $ctrl = $self->format_control($state->control);
        my $kont = $state->kont->type;
        return "[$ctrl | $kont]";
    }

    method format_control($c) {
        return $c->type . ":" . ($c->can('value') ? $c->value :
                                 $c->can('name')  ? $c->name  :
                                 $c->can('n')     ? $c->n     :
                                 $c->can('s')     ? $c->s     : '?');
    }
}

# =============================================================================
# PARSER
# =============================================================================

class Parser {

    method tokenize($s) {
        my @tokens;
        my $i = 0;
        my $len = length($s);

        while ($i < $len) {
            my $c = substr($s, $i, 1);

            # Skip whitespace
            if ($c =~ /\s/) { $i++; next; }

            # Skip comments
            if ($c eq ';') {
                while ($i < $len && substr($s, $i, 1) ne "\n") { $i++; }
                next;
            }

            # Parens
            if ($c eq '(' || $c eq ')') {
                push @tokens, $c;
                $i++;
                next;
            }

            # Quote shorthand
            if ($c eq "'") {
                push @tokens, "'";
                $i++;
                next;
            }

            # Symbol or number
            my $token = '';
            while ($i < $len) {
                $c = substr($s, $i, 1);
                last if $c =~ /[\s()']/;
                $token .= $c;
                $i++;
            }
            push @tokens, $token if length $token;
        }

        return \@tokens;
    }

    method parse($tokens) {
        die "unexpected EOF" if @$tokens == 0;

        my $token = shift @$tokens;

        # Quote shorthand
        if ($token eq "'") {
            my $quoted = $self->parse($tokens);
            return { type => 'list', elements => [ SymExpr->new(name => 'quote'), $quoted ] };
        }

        # List
        if ($token eq '(') {
            my @elements;
            while (@$tokens && $tokens->[0] ne ')') {
                push @elements, $self->parse($tokens);
            }
            die "unexpected EOF: missing ')'" if @$tokens == 0;
            shift @$tokens;  # remove ')'
            return { type => 'list', elements => \@elements };
        }

        die "unexpected )" if $token eq ')';

        # Number
        if ($token =~ /^-?\d+$/) {
            return NumExpr->new(value => int($token));
        }

        # Symbol
        return SymExpr->new(name => $token);
    }

    method to_expr($parsed) {
        # Already an expression object
        return $parsed if $parsed isa NumExpr || $parsed isa SymExpr;

        die "unexpected: $parsed" unless ref($parsed) eq 'HASH' && $parsed->{type} eq 'list';

        my @elements = @{$parsed->{elements}};

        # Empty list
        return QuoteExpr->new(datum => { type => 'nil' }) if @elements == 0;

        my $head = $elements[0];

        # Special forms
        if ($head isa SymExpr) {
            my $name = $head->name;

            if ($name eq 'quote') {
                return QuoteExpr->new(datum => $elements[1]);
            }

            if ($name eq 'if') {
                my $else_expr = (@elements > 3)
                    ? $self->to_expr($elements[3])
                    : QuoteExpr->new(datum => { type => 'nil' });
                return IfExpr->new(
                    test => $self->to_expr($elements[1]),
                    then => $self->to_expr($elements[2]),
                    else => $else_expr
                );
            }

            if ($name eq 'lambda') {
                my $params = [ map { $_->name } @{$elements[1]->{elements}} ];
                return LamExpr->new(
                    params => $params,
                    body   => $self->to_expr($elements[2])
                );
            }

            if ($name eq 'let') {
                # (let ((x v) ...) body) => ((lambda (x ...) body) v ...)
                my @bindings = @{$elements[1]->{elements}};
                my @params = map { $_->{elements}[0]->name } @bindings;
                my @args   = map { $self->to_expr($_->{elements}[1]) } @bindings;
                return AppExpr->new(
                    fn   => LamExpr->new(params => \@params, body => $self->to_expr($elements[2])),
                    args => \@args
                );
            }

            if ($name eq 'begin') {
                # (begin e1 e2 ...) => ((lambda (_) e2...) e1)
                return $self->to_expr($elements[1]) if @elements == 2;
                my $first = $self->to_expr($elements[1]);
                my $rest  = $self->to_expr({ type => 'list', elements => [ SymExpr->new(name => 'begin'), @elements[2..$#elements] ] });
                return AppExpr->new(
                    fn   => LamExpr->new(params => ['_'], body => $rest),
                    args => [$first]
                );
            }

            if ($name eq 'define') {
                # Special - handled in REPL
                return { type => 'define', name => $elements[1]->name, value => $self->to_expr($elements[2]) };
            }
        }

        # Application
        return AppExpr->new(
            fn   => $self->to_expr($head),
            args => [ map { $self->to_expr($_) } @elements[1..$#elements] ]
        );
    }

    method parse_expr($s) {
        my $tokens = $self->tokenize($s);
        my $parsed = $self->parse($tokens);
        return $self->to_expr($parsed);
    }
}

# =============================================================================
# FORMATTER
# =============================================================================

sub format_value($v) {
    return '<undef>' unless defined $v;
    my $type = $v->type;
    return $v->n                                    if $type eq 'num';
    return $v->s                                    if $type eq 'sym';
    return 'nil'                                    if $type eq 'nil';
    return '(' . format_list($v) . ')'              if $type eq 'cons';
    return '<lambda (' . join(' ', @{$v->params}) . ')>' if $type eq 'lambda';
    return '<primitive ' . $v->name . '>'           if $type eq 'primitive';
    return '<continuation>'                         if $type eq 'continuation';
    return "<unknown: $type>";
}

sub format_list($v) {
    my @parts;
    my $cur = $v;
    while ($cur->type eq 'cons') {
        push @parts, format_value($cur->car);
        $cur = $cur->cdr;
    }
    if ($cur->type ne 'nil') {
        push @parts, '.', format_value($cur);
    }
    return join(' ', @parts);
}

# =============================================================================
# PRIMITIVES
# =============================================================================

sub make_primitives($executor) {
    return {
        # Constants
        'nil'   => NIL(),
        'true'  => NumVal->new(n => 1),
        'false' => NIL(),

        # Arithmetic
        '+' => PrimVal->new(name => '+', impl => sub ($args, $, $) {
            my $sum = 0;
            $sum += $_->n for @$args;
            NumVal->new(n => $sum);
        }),
        '-' => PrimVal->new(name => '-', impl => sub ($args, $, $) {
            return NumVal->new(n => -$args->[0]->n) if @$args == 1;
            NumVal->new(n => $args->[0]->n - $args->[1]->n);
        }),
        '*' => PrimVal->new(name => '*', impl => sub ($args, $, $) {
            my $prod = 1;
            $prod *= $_->n for @$args;
            NumVal->new(n => $prod);
        }),
        '/' => PrimVal->new(name => '/', impl => sub ($args, $, $) {
            NumVal->new(n => int($args->[0]->n / $args->[1]->n));
        }),
        'mod' => PrimVal->new(name => 'mod', impl => sub ($args, $, $) {
            NumVal->new(n => $args->[0]->n % $args->[1]->n);
        }),

        # Comparison
        '=' => PrimVal->new(name => '=', impl => sub ($args, $, $) {
            $args->[0]->n == $args->[1]->n ? NumVal->new(n => 1) : NIL();
        }),
        '<' => PrimVal->new(name => '<', impl => sub ($args, $, $) {
            $args->[0]->n < $args->[1]->n ? NumVal->new(n => 1) : NIL();
        }),
        '>' => PrimVal->new(name => '>', impl => sub ($args, $, $) {
            $args->[0]->n > $args->[1]->n ? NumVal->new(n => 1) : NIL();
        }),
        '<=' => PrimVal->new(name => '<=', impl => sub ($args, $, $) {
            $args->[0]->n <= $args->[1]->n ? NumVal->new(n => 1) : NIL();
        }),
        '>=' => PrimVal->new(name => '>=', impl => sub ($args, $, $) {
            $args->[0]->n >= $args->[1]->n ? NumVal->new(n => 1) : NIL();
        }),

        # Lists
        'cons' => PrimVal->new(name => 'cons', impl => sub ($args, $, $) {
            ConsVal->new(car => $args->[0], cdr => $args->[1]);
        }),
        'car' => PrimVal->new(name => 'car', impl => sub ($args, $, $) {
            $args->[0]->car;
        }),
        'cdr' => PrimVal->new(name => 'cdr', impl => sub ($args, $, $) {
            $args->[0]->cdr;
        }),
        'list' => PrimVal->new(name => 'list', impl => sub ($args, $, $) {
            my $result = NIL();
            $result = ConsVal->new(car => $_, cdr => $result) for reverse @$args;
            $result;
        }),
        'null?' => PrimVal->new(name => 'null?', impl => sub ($args, $, $) {
            $args->[0]->type eq 'nil' ? NumVal->new(n => 1) : NIL();
        }),
        'pair?' => PrimVal->new(name => 'pair?', impl => sub ($args, $, $) {
            $args->[0]->type eq 'cons' ? NumVal->new(n => 1) : NIL();
        }),

        # Type predicates
        'number?' => PrimVal->new(name => 'number?', impl => sub ($args, $, $) {
            $args->[0]->type eq 'num' ? NumVal->new(n => 1) : NIL();
        }),
        'symbol?' => PrimVal->new(name => 'symbol?', impl => sub ($args, $, $) {
            $args->[0]->type eq 'sym' ? NumVal->new(n => 1) : NIL();
        }),
        'procedure?' => PrimVal->new(name => 'procedure?', impl => sub ($args, $, $) {
            my $t = $args->[0]->type;
            ($t eq 'lambda' || $t eq 'primitive' || $t eq 'continuation')
                ? NumVal->new(n => 1) : NIL();
        }),

        # I/O
        'print' => PrimVal->new(name => 'print', impl => sub ($args, $, $) {
            say format_value($args->[0]);
            NIL();
        }),
        'display' => PrimVal->new(name => 'display', impl => sub ($args, $, $) {
            print format_value($args->[0]);
            NIL();
        }),
        'newline' => PrimVal->new(name => 'newline', impl => sub ($args, $, $) {
            print "\n";
            NIL();
        }),

        # call/cc - handled specially in apply_fn, but we need the primitive entry
        'call/cc' => PrimVal->new(name => 'call/cc', impl => sub ($args, $env, $kont) {
            die "call/cc should be handled in apply_fn";
        }),

        # Async primitive: delay - returns value after ms milliseconds
        # Usage: (delay ms value) - waits ms then returns value
        'delay' => PrimVal->new(name => 'delay', impl => sub ($args, $, $) {
            my $ms = $args->[0]->n;
            my $val = @$args > 1 ? $args->[1] : NIL();
            my $promise = Promise->new(executor => $executor);

            # Use ScheduledExecutor for real-time delays
            $executor->schedule_delayed(sub {
                $promise->resolve($val);
            }, $ms);

            return $promise;
        }),

        # sleep - delay that returns nil (for side-effect timing)
        'sleep' => PrimVal->new(name => 'sleep', impl => sub ($args, $, $) {
            my $ms = $args->[0]->n;
            my $promise = Promise->new(executor => $executor);

            $executor->schedule_delayed(sub {
                $promise->resolve(NIL());
            }, $ms);

            return $promise;
        }),

        # now - returns current time in milliseconds (for timing)
        'now' => PrimVal->new(name => 'now', impl => sub ($args, $, $) {
            require Time::HiRes;
            NumVal->new(n => int(Time::HiRes::time() * 1000));
        }),
    };
}

# =============================================================================
# REPL
# =============================================================================

sub repl {
    my $executor = ScheduledExecutor->new;  # Use ScheduledExecutor for delay/sleep
    my $parser   = Parser->new;
    my $cek      = CEK->new(executor => $executor, trace => 0);

    my $prims = make_primitives($executor);
    my $env   = Env->new(bindings => $prims);

    say "CEK Lisp - Perl Edition";
    say "Type 'quit' to exit, 'trace' to toggle tracing";
    say "Features: lambda, if, let, define, quote, call/cc, delay, sleep, now";
    say "";

    print "> ";
    while (my $line = <STDIN>) {
        chomp $line;

        last if $line eq 'quit' || $line eq 'exit';

        if ($line eq 'trace') {
            my $on = $cek->toggle_trace;
            say "Tracing: " . ($on ? "ON" : "OFF");
            print "> ";
            next;
        }

        next if $line =~ /^\s*$/ || $line =~ /^\s*;/;

        eval {
            my $expr = $parser->parse_expr($line);

            # Handle define specially
            if (ref($expr) eq 'HASH' && $expr->{type} eq 'define') {
                my $promise = $cek->run($expr->{value}, $env);
                if ($promise->is_resolved) {
                    my $val = $promise->result;
                    $env->define($expr->{name}, $val);
                    say "$expr->{name} = " . format_value($val);
                } elsif ($promise->is_rejected) {
                    say "Error: " . $promise->error;
                }
            } else {
                my $promise = $cek->run($expr, $env);
                if ($promise->is_resolved) {
                    say format_value($promise->result);
                } elsif ($promise->is_rejected) {
                    say "Error: " . $promise->error;
                }
            }
        };
        if ($@) {
            say "Error: $@";
        }

        print "> ";
    }

    say "Goodbye!";
}

# =============================================================================
# MAIN
# =============================================================================

# Run some tests if called with --test
if (@ARGV && $ARGV[0] eq '--test') {
    say "Running tests...";

    my $executor = ScheduledExecutor->new;  # Use ScheduledExecutor for delay/sleep
    my $parser   = Parser->new;
    my $cek      = CEK->new(executor => $executor);
    my $prims    = make_primitives($executor);
    my $env      = Env->new(bindings => $prims);

    my @tests = (
        # Basic arithmetic
        ['(+ 1 2 3)', '6'],
        ['(* 2 3 4)', '24'],
        ['(- 10 3)', '7'],

        # Conditionals
        ['(if (= 1 1) 42 0)', '42'],
        ['(if (= 1 2) 42 0)', '0'],

        # Lambda and application
        ['((lambda (x) (* x x)) 5)', '25'],
        ['((lambda (x y) (+ x y)) 3 4)', '7'],
        ['(let ((x 10) (y 20)) (+ x y))', '30'],

        # Lists
        ['(car (cons 1 2))', '1'],
        ['(cdr (cons 1 2))', '2'],
        ['(null? nil)', '1'],
        ['(null? 42)', 'nil'],
        ["'(1 2 3)", '(1 2 3)'],
        ['(car (list 1 2 3))', '1'],

        # call/cc - basic escape
        ['(+ 1 (call/cc (lambda (k) (+ 2 (k 10)))))', '11'],

        # call/cc - without invoking continuation
        ['(call/cc (lambda (k) 42))', '42'],

        # call/cc - early return pattern
        ['(+ 10 (call/cc (lambda (return) (+ 1 (return 5)))))', '15'],
    );

    my $passed = 0;
    my $failed = 0;

    for my $test (@tests) {
        my ($input, $expected) = @$test;
        my $expr = $parser->parse_expr($input);
        my $promise = $cek->run($expr, $env);
        my $result = format_value($promise->result);

        if ($result eq $expected) {
            say "PASS: $input => $result";
            $passed++;
        } else {
            say "FAIL: $input => $result (expected $expected)";
            $failed++;
        }
    }

    say "";
    say "Results: $passed passed, $failed failed";
    exit($failed > 0 ? 1 : 0);
}

# Otherwise run REPL
repl();
