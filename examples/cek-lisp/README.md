# CEK Lisp - A Mini-Lisp with First-Class Continuations

A small Lisp interpreter built on the CEK abstract machine model, demonstrating
how grey::static's concurrency primitives can be used to build an interpreter
with async support and first-class continuations.

## Overview

The CEK machine is a well-studied abstract machine for evaluating lambda calculus
expressions. The name comes from its three registers:

- **C** (Control): The expression being evaluated, or a computed value
- **E** (Environment): Current variable bindings
- **K** (Kontinuation): What to do with the result

The key insight is that **continuations are data structures**, not implicit in
the call stack. This enables:

- `call/cc` (call with current continuation)
- Async primitives that suspend and resume evaluation
- Step-by-step debugging and tracing
- Pausable/resumable computation

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    CEK Machine                              │
├─────────────────────────────────────────────────────────────┤
│  step() : State → State | Promise<State>                    │
│    ├── step_expr() : handle expressions                     │
│    ├── step_kont() : handle continuations                   │
│    └── apply_fn()  : function application                   │
├─────────────────────────────────────────────────────────────┤
│  Trampoline Driver (using Executor)                         │
│    - Schedules steps via next_tick()                        │
│    - Handles Promise returns for async primitives           │
│    - Returns Promise<Value> for final result                │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│              grey::static Components                        │
├─────────────────────────────────────────────────────────────┤
│  ScheduledExecutor                                          │
│    - Event loop with next_tick() scheduling                 │
│    - Real-time delays via schedule_delayed()                │
│                                                             │
│  Promise                                                    │
│    - Async value containers                                 │
│    - then() for continuation chaining                       │
│    - Used for async primitive return values                 │
└─────────────────────────────────────────────────────────────┘
```

## Design Decisions

### Why Not Full Reactive Streams?

The original design document proposed using reactive streams (like RxJS or
Project Reactor) where `flatMap` embodies CPS bind semantics. While elegant,
this would require implementing several missing operators in grey::static:

- `flatMap` / `mergeMap` (CPS bind)
- `expand` (recursive state machine driver)
- `of` / `empty` / `throwError` (single-value publishers)
- `toArray` / `collect`
- `defaultIfEmpty`

Instead, we chose a **simpler hybrid approach**:

1. **Promise for async** - grey::static's Promise already has `then()` which
   IS continuation-passing style
2. **Executor for scheduling** - The trampoline uses `next_tick()` to avoid
   stack overflow on deep recursion
3. **Explicit state machine** - The CEK registers are plain data structures

This gives us the same capabilities with much less implementation effort.

### Trampoline Pattern

The CEK machine naturally converts recursion to iteration:

```perl
method trampoline($state, $final_promise, $step_count) {
    $executor->next_tick(sub {
        if ($state->is_done) {
            $final_promise->resolve($state->value);
            return;
        }

        my $result = $self->step($state);

        if ($result isa Promise) {
            # Async step - wait for it
            $result->then(sub ($next_state) {
                $self->trampoline($next_state, $final_promise, $step_count + 1);
            });
        } else {
            # Sync step - continue
            $self->trampoline($result, $final_promise, $step_count + 1);
        }
    });
}
```

Each step is scheduled via `next_tick()`, preventing stack overflow even for
deeply recursive programs.

## Components

### Values

| Type | Description |
|------|-------------|
| `NumVal` | Numbers |
| `SymVal` | Symbols |
| `ConsVal` | Cons cells (pairs) |
| `NilVal` | Empty list / false |
| `LambdaVal` | Closures (params, body, captured env) |
| `PrimVal` | Built-in primitives |
| `ContVal` | Reified continuations (for call/cc) |

### Expressions (AST)

| Type | Description |
|------|-------------|
| `NumExpr` | Number literal |
| `SymExpr` | Variable reference |
| `IfExpr` | Conditional |
| `LamExpr` | Lambda expression |
| `AppExpr` | Function application |
| `QuoteExpr` | Quoted datum |

### Kontinuations

| Type | Description |
|------|-------------|
| `HaltK` | Top-level - evaluation complete |
| `IfK` | Waiting for test result to pick branch |
| `FnK` | Evaluated function, waiting to eval args |
| `ArgK` | Evaluating arguments one by one |

### Environment

Linked structure with lexical scoping:

```perl
class Env {
    field $bindings;  # name => value hash
    field $parent;    # enclosing scope

    method lookup($name) { ... }
    method extend($names, $values) { ... }  # returns new Env
}
```

## Features

### Core Language

- **lambda** - `(lambda (x y) (+ x y))`
- **if** - `(if test then else)`
- **let** - `(let ((x 1) (y 2)) (+ x y))` (desugared to lambda)
- **define** - `(define name value)` (REPL only)
- **quote** - `'(1 2 3)` or `(quote datum)`
- **begin** - `(begin e1 e2 ...)` (desugared)

### Primitives

**Arithmetic:** `+`, `-`, `*`, `/`, `mod`

**Comparison:** `=`, `<`, `>`, `<=`, `>=`

**Lists:** `cons`, `car`, `cdr`, `list`, `null?`, `pair?`

**Type predicates:** `number?`, `symbol?`, `procedure?`

**I/O:** `print`, `display`, `newline`

**Control:** `call/cc`

**Timing:** `delay`, `sleep`, `now`

### call/cc (First-Class Continuations)

```lisp
; Basic escape - k aborts the (+ 2 ...) and returns 10 directly
(+ 1 (call/cc (lambda (k) (+ 2 (k 10)))))
; => 11

; Early return pattern
(+ 10 (call/cc (lambda (return)
  (if (= 1 1)
      (return 5)    ; escape early
      (+ 100 200)))))
; => 15
```

### Async Primitives

```lisp
; delay - wait ms, return value
(delay 100 42)  ; waits 100ms, returns 42

; sleep - wait ms, return nil
(sleep 500)     ; waits 500ms

; now - current time in milliseconds
(define t1 (now))
(sleep 100)
(- (now) t1)    ; => ~100
```

## Usage

### Run Tests

```bash
cd examples/cek-lisp
perl cek-lisp.pl --test
```

### Interactive REPL

```bash
perl cek-lisp.pl
```

```
CEK Lisp - Perl Edition
Type 'quit' to exit, 'trace' to toggle tracing
Features: lambda, if, let, define, quote, call/cc, delay, sleep, now

> (+ 1 2 3)
6
> (define fact (lambda (n) (if (= n 0) 1 (* n (fact (- n 1))))))
fact = <lambda (n)>
> (fact 5)
120
> (call/cc (lambda (k) (+ 1 (k 42))))
42
> quit
Goodbye!
```

### Tracing

Toggle step-by-step tracing with `trace`:

```
> trace
Tracing: ON
> (+ 1 2)
step 0: [app:? | halt]
step 1: [sym:+ | fn]
step 2: [primitive:+ | fn]
step 3: [num:1 | arg]
step 4: [num:1 | arg]
step 5: [num:2 | arg]
step 6: [num:2 | arg]
step 7: [num:3 | halt]
3
```

## Examples

### Countdown with Real Delays

```lisp
(define countdown
  (lambda (n)
    (if (= n 0)
        (print 'done)
        (begin
          (print n)
          (sleep 500)
          (countdown (- n 1))))))

(countdown 3)
; prints: 3, 2, 1, done (with 500ms between each)
```

### Using call/cc for Early Exit

```lisp
(define find-first
  (lambda (pred lst)
    (call/cc (lambda (return)
      (define loop
        (lambda (l)
          (if (null? l)
              nil
              (if (pred (car l))
                  (return (car l))
                  (loop (cdr l))))))
      (loop lst)))))

(find-first (lambda (x) (> x 5)) '(1 3 7 2 9))
; => 7
```

### Timing Measurements

```lisp
(define time-it
  (lambda (thunk)
    (let ((t1 (now)))
      (let ((result (thunk)))
        (let ((elapsed (- (now) t1)))
          (begin
            (display 'elapsed:)
            (display elapsed)
            (display 'ms)
            (newline)
            result))))))

(time-it (lambda () (sleep 100) 42))
; elapsed: 101 ms
; => 42
```

## Relationship to the Design Document

This implementation validates the core thesis from `reactive-cps-interpreter.md`:

> "Reactive streams already embody continuation-passing style semantics"

While we didn't use full reactive streams, we demonstrated that:

1. **Promise `then()` IS CPS** - it takes a continuation as argument
2. **Executor scheduling enables trampolining** - prevents stack overflow
3. **Explicit continuations as data** - enables call/cc trivially
4. **Async primitives just work** - return Promise, driver handles it

The hybrid approach gives us the benefits (async, call/cc, debugging) without
the complexity of implementing `flatMap`, `expand`, etc.

## Future Directions

- **More special forms**: `cond`, `and`, `or`, `case`
- **Macros**: Hygienic macro system
- **Module system**: Import/export bindings
- **Tail call optimization**: Detect and optimize tail calls
- **Error handling**: `try`/`catch` with continuation-based exceptions
- **Parallel evaluation**: Evaluate independent arguments concurrently
