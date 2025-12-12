# grey::static Pattern System

## Overview

This document proposes evolving grey::static from a curated module loader into a pattern-based development system. The core library already embodies composable patterns—this work makes them explicit, machine-actionable, and AI-assistable.

The goal is a personal development environment where:

- Patterns you use regularly are formally defined
- An AI agent understands those patterns deeply
- You code when you want precision, describe when you want speed
- The system fills in mechanical details using patterns it knows you trust

This is not a no-code platform. It's augmentation for developers who understand the patterns they're composing but can't always keep every detail in their heads.

---

## What Already Exists

grey::static already has implicit patterns throughout:

### Stream Pipeline Pattern
```perl
Stream->of(@items)
    ->map(sub { ... })
    ->grep(sub { ... })
    ->collect(Collector);
```

### Reactive Subscription Pattern
```perl
Flow->from($publisher)
    ->map(sub { ... })
    ->filter(sub { ... })
    ->to(sub { ... })
    ->build;
```

### Event Loop Pattern
```perl
Time->of_delta()
    ->peek(sub ($dt) { capture_input() })
    ->peek(sub ($dt) { update_state($dt) })
    ->peek(sub ($dt) { render() })
    ->sleep_for($frame_time)
    ->take($max_frames)
    ->foreach(Consumer->new(f => sub { }));
```

### Functional Composition Pattern
```perl
my $f = Function->new(f => sub { ... });
my $g = Function->new(f => sub { ... });
my $composed = $f->and_then($g);
```

### Result/Option Error Handling Pattern
```perl
my $result = try_operation();
$result->is_ok ? $result->unwrap : handle_error($result);
```

These patterns compose. Stream + io::stream gives file processing. Stream + time::stream gives animation loops. Reactive + tty::graphics gives interactive applications.

---

## Proposed Additions

### 1. Pattern Definitions

A `patterns/` directory containing formal pattern specifications:

```
patterns/
  stream-pipeline.pattern
  reactive-flow.pattern
  event-loop.pattern
  functional-composition.pattern
  error-handling.pattern
```

Each pattern definition is an s-expression that captures:

- **Structure**: What components are involved, how they connect
- **Constraints**: What's required, what's optional, valid configurations
- **Variations**: Named variants of the pattern (e.g., "event loop with fixed timestep" vs "variable timestep")
- **Composition rules**: How this pattern combines with others
- **Examples**: Canonical instances for training/reference

### 2. Pattern Language

A minimal Kernel-style fexpr language for pattern definitions. Patterns receive AST + context and produce:

- Scaffolded code
- Validation results
- Suggested completions
- Migration paths between pattern versions

Example sketch (syntax TBD):

```scheme
(define-pattern stream-pipeline
  (components
    (source   :required (one-of Stream->of Stream->iterate IO::Stream::*))
    (stages   :zero-or-more (one-of map grep flatmap peek take skip))
    (terminal :required (one-of collect foreach reduce)))
  
  (constraints
    (after take (not skip))  ; skip after take is usually wrong
    (terminal-requires-collector (when (eq terminal collect) (requires collector))))
  
  (variations
    (lazy-file-processing
      :source IO::Stream::Files->lines
      :description "Process file line by line without loading into memory")
    (infinite-generator
      :source Stream->iterate
      :requires (one-of take limit timeout)
      :description "Infinite stream, must have termination condition"))
  
  (composes-with
    time::stream  ; enables throttle, debounce, timeout
    functional))  ; enables typed Function/Predicate wrappers
```

### 3. Knowledge Base

Documentation that serves both humans and AI:

```
docs/
  patterns/
    stream-pipeline.md      # Human-readable explanation
    stream-pipeline.examples # Annotated examples with rationale
  rationale/
    why-lazy-streams.md     # Design decisions
    composing-reactive.md   # How components fit together
```

The AI agent is trained on (or has access to) this knowledge base. When you say "process this log file and find errors", it knows:

- stream-pipeline pattern applies
- io::stream provides the source
- grep stage with a predicate for filtering
- What collector makes sense for the output

### 4. Project Structure

```
my-project/
  src/                    # Application code
  patches/                # Overrides to grey::static if needed
  patterns/               # Project-specific patterns (if any)
  compose.spec            # How components connect (for larger projects)
  deps.lock               # Pinned grey::static version
```

### 5. AI Integration Points

The AI agent operates at several levels:

**Pattern selection**: "I need to process events from multiple sources" → suggests reactive-flow with merge

**Code generation**: Given a selected pattern and parameters, generates conformant code

**Completion**: While editing, suggests pattern-aware completions

**Validation**: Checks that code matches pattern constraints, warns on anti-patterns

**Explanation**: "Why did you use peek here instead of map?" → explains side-effect semantics

---

## Example Workflow

Developer wants to build a simple log monitor that tails a file and highlights errors.

**Approach 1: Describe to AI**

> "Watch access.log, filter for lines containing ERROR, colorize them red, print to terminal"

AI recognizes:
- io::stream for file watching (or time::stream + file polling)
- stream-pipeline pattern
- tty::ansi for colorization
- foreach terminal to print

Generates:

```perl
use grey::static qw[ functional stream io::stream tty::ansi ];

IO::Stream::Files->lines('access.log')
    ->grep(sub ($line) { $line =~ /ERROR/ })
    ->map(sub ($line) { ANSI::red($line) })
    ->foreach(Consumer->new(f => sub ($line) { say $line }));
```

**Approach 2: Start coding, AI assists**

Developer types:

```perl
use grey::static qw[ io::stream stream ];

IO::Stream::Files->lines('access.log')
    ->grep
```

AI sees incomplete stream pipeline, offers:

- Completion for grep predicate
- Suggestion: "filtering for a pattern? here's the common form"
- Warning if developer tries to add stages after a terminal

**Approach 3: Mixed**

Developer writes the structure, asks AI to fill in:

```perl
# TODO: filter for errors, colorize, print
IO::Stream::Files->lines('access.log')
    ->???
```

AI expands the TODO based on pattern knowledge.

---

## Implementation Phases

### Phase 1: Document Existing Patterns

Before building tooling, capture what's already there:

- Identify the 5-10 core patterns in grey::static
- Write human-readable pattern documentation
- Create annotated examples showing composition
- Document design rationale

This is valuable regardless of whether the rest gets built.

### Phase 2: Pattern Definition Format

Design and implement the pattern language:

- S-expression parser
- Pattern definition schema
- Constraint representation
- Basic validation (does code match pattern?)

Start with 2-3 patterns to prove the format works.

### Phase 3: AI Integration (Cloud)

Before training local models:

- Create prompts that include pattern definitions as context
- Test with cloud models (Claude, GPT-4) 
- Measure: does structured pattern context improve generation quality?
- Iterate on pattern format based on what helps the AI

### Phase 4: Knowledge Base Structure

Organize documentation for dual human/AI consumption:

- Rationale docs
- Example corpus with annotations
- Anti-pattern documentation (what not to do)

### Phase 5: Local Model Exploration

Once patterns and knowledge base are solid:

- Experiment with fine-tuning small models
- Test pattern-constrained generation
- Implement confidence/escalation logic

### Phase 6: Tooling

- Editor integration (LSP or similar)
- Pattern-aware completion
- Validation warnings
- Scaffold generation

---

## Open Questions

### Pattern Granularity

How fine-grained should patterns be?

- "Stream pipeline" as one pattern, or "map stage", "grep stage", "collect terminal" as separate composable micro-patterns?
- Probably start coarse, refine based on what's useful

### Constraint Language

How expressive do constraints need to be?

- Simple: "requires X", "incompatible with Y"
- Complex: "if source is infinite, must have termination"
- Start simple, extend as needed

### Composition Specification

For single-file scripts, composition is implicit (it's all in one process). When does explicit composition matter?

- Multi-process architectures
- Service boundaries  
- Probably not needed for Phase 1

### Patch Format

If someone needs to patch grey::static behavior:

- Unified diff?
- Semantic patch (AST-level)?
- Method override declarations?

Perl's flexibility makes this both easier and harder.

---

## Relationship to Broader Vision

This work on grey::static is a proving ground for the larger pattern-based development system discussed separately. If patterns can be formalized and made useful here, the approach can generalize to:

- Other languages (emit patterns to TypeScript, Rust, etc.)
- Larger architectures (composition language for services)
- Team environments (shared pattern libraries)

But that's future work. The immediate goal is: make grey::static development faster and more reliable through explicit, AI-assistable patterns.

---

## Next Steps

1. Review this proposal, adjust scope
2. Pick 2-3 patterns to formalize first (stream-pipeline and event-loop seem good candidates)
3. Draft pattern definitions in proposed s-expression format
4. Write supporting documentation
5. Test with AI (does the context help?)
6. Iterate

---

## Appendix: Pattern Candidates

Patterns already visible in grey::static, candidates for formalization:

| Pattern | Components | Notes |
|---------|------------|-------|
| Stream Pipeline | stream, functional, collectors | Core lazy processing |
| Reactive Flow | concurrency::reactive, functional | Backpressure, async |
| Event Loop | time::stream, tty::*, functional | Input/update/render cycle |
| Shader Render | tty::graphics, datatypes::numeric | Pixel-level graphics |
| Promise Chain | concurrency::util | Async with then/catch |
| Functional Composition | functional | Function/Predicate combinators |
| Option Handling | datatypes::util | Some/None patterns |
| Result Handling | datatypes::util | Ok/Error patterns |
| File Processing | io::stream, stream | Directory walks, line processing |
| Time-Based Stream | time::stream, stream | Delta time, throttling |

Not all need immediate formalization. Start with the most commonly composed ones.
