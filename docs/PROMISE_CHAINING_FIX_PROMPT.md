# Prompt: Fix Promise Chaining with Delayed Promises

## Objective

Fix Promise->then() to properly chain delayed promises. Currently, when a `then()` callback returns a delayed promise, the final `then()` handler is not invoked.

## Current Status

**Working:**
- Simple promise chains work fine
- Chaining non-delayed promises works
- Single level of delayed promises works

**Broken:**
- Complex chains where `then()` callbacks return delayed promises
- Second promise in chain doesn't trigger final handlers

## The Problem

### Failing Test Scenario

```perl
my $executor = ScheduledExecutor->new;
my @results;

my $fetch_user = sub ($id) {
    return Promise->delay("User_$id", 10, $executor)
        ->timeout(20, $executor);
};

my $fetch_posts = sub ($user) {
    push @results, $user;  # This executes ✅
    return Promise->delay(["Post1", "Post2"], 15, $executor)
        ->timeout(25, $executor);
};

$fetch_user->(123)
    ->then($fetch_posts)
    ->then(
        sub ($posts) { push @results, join(",", @$posts) },  # ❌ NEVER CALLED
        sub ($err)   { push @results, "Failed: $err" }
    );

$executor->run;

# Expected: ["User_123", "Post1,Post2"]
# Actual:   ["User_123"]
```

### Observations

1. First promise (fetch_user) completes successfully at t=10
2. fetch_posts callback IS invoked (user pushed to @results)
3. Second delayed promise IS created (timers exist in wheel)
4. Second promise delay completes at t=25
5. **BUT** final then() handlers are never invoked
6. Executor stops with timers still in wheel (timer_count = 2)

### Root Cause Hypothesis

The issue appears to be in how Promise->then() handles promises returned from callbacks. When the callback returns a new promise:

1. The new promise needs to be "chained" to the parent promise
2. The parent's then() handlers should wait for the returned promise
3. Currently, the connection between the returned promise and the parent's handlers is broken

## Files to Investigate

### Primary Investigation

**`lib/grey/static/concurrency/util/Promise.pm`:**
- Focus on the `then()` method implementation
- Look for how it handles promises returned from callbacks
- Check if there's a missing link between returned promises and handlers

### Key Code Sections

```perl
# In Promise->then(), when a callback returns a promise:
method then ($on_success = undef, $on_failure = undef) {
    # ... existing code ...

    # Somewhere in here, when $on_success->apply($result) returns a Promise,
    # we need to chain that promise's resolution to trigger $new_promise
}
```

## Debugging Strategy

### Step 1: Add Debug Output

Add temporary debug output to Promise.pm to trace execution:

```perl
method then ($on_success = undef, $on_failure = undef) {
    say "then() called on promise $self";

    # ... existing code ...

    if (ref($callback_result) && $callback_result->isa('Promise')) {
        say "Callback returned a promise: $callback_result";
        # How do we handle this?
    }
}
```

### Step 2: Test Simplified Scenario

Create a minimal test case:

```perl
my $executor = ScheduledExecutor->new;
my $result;

Promise->delay("A", 10, $executor)
    ->then(sub ($x) {
        say "First then: $x";
        return Promise->delay("B", 5, $executor);
    })
    ->then(sub ($x) {
        say "Second then: $x";
        $result = $x;
    });

$executor->run;

# Should print:
#   First then: A
#   Second then: B
# And $result should be "B"
```

### Step 3: Check Promise Resolution Flow

Trace how promises resolve:
1. When first promise resolves with "A"
2. First then() callback is invoked, returns Promise
3. **Question:** Is that returned Promise connected to the chain?
4. When returned Promise resolves with "B"
5. **Question:** Does it trigger the second then() callback?

## Expected Fix Pattern

The fix likely involves detecting when a callback returns a Promise and "flattening" it:

```perl
method then ($on_success = undef, $on_failure = undef) {
    # ... setup new_promise ...

    # In the handler that gets added to $handlers:
    my $handler = sub ($value) {
        my $result = $on_success->apply($value);

        # KEY FIX: Check if result is a Promise
        if (ref($result) && $result->isa('Promise')) {
            # Chain the returned promise to new_promise
            $result->then(
                sub ($v) { $new_promise->resolve($v) },
                sub ($e) { $new_promise->reject($e) }
            );
        } else {
            # Normal value, resolve immediately
            $new_promise->resolve($result);
        }
    };

    # ... rest of implementation ...
}
```

## Reference: p7 Implementation

Check how p7 handles this:
- **File:** `/Users/stevan/Projects/perl/p7/lib/org/p7/util/concurrent/Promise.pm`
- Look for "promise flattening" or "promise chaining" logic
- The p7 version likely has this working correctly

## Success Criteria

✅ Simplified test case passes (A -> B chain)
✅ Complex chain test passes (fetch_user -> fetch_posts)
✅ All 16 promise timeout tests pass (no skips)
✅ No regressions in existing promise tests
✅ Full test suite still passing

## Test File

**Location:** `t/grey/static/04-concurrency/031-promise-timeout.t`

**Currently Skipped Test:** Line 196-224 (test 11, "timeout - complex promise chain")

After fix, remove the SKIP block and verify test passes.

## Expected Outcome

**Modified File:**
- `lib/grey/static/concurrency/util/Promise.pm` - Fix then() to handle returned promises

**Test Results:**
- Promise timeout tests: 16/16 passing ✅
- Full test suite: Still passing ✅

## Tips

1. **Promise flattening** is a common pattern in promise implementations
2. The key is detecting when a callback returns a Promise
3. That returned Promise needs to be "unwrapped" and its result passed to the next handler
4. This is sometimes called "thenable chaining"
5. Focus on the `then()` method - that's where the magic happens

Good luck! This should be a focused fix in Promise.pm's then() method. 🚀
