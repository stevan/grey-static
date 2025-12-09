# Prompt: Fix ScheduledExecutor Test Hangs

## Context

The Timer::Wheel + Executor integration is mostly complete, but the ScheduledExecutor tests hang when run with `prove -l t/`. The tests pass up through "immediate callbacks (delay 0)" but then hang on subsequent tests.

## Current Status

**Working:**
- Timer cancellation (7 tests, all passing)
- Timer::Wheel find_next_timeout bug fixed
- ScheduledExecutor basic functionality works
- First 6 subtests of `t/grey/static/04-concurrency/030-scheduled-executor.t` pass

**Problem:**
- Tests hang somewhere after subtest 6 when run with prove
- Need to identify which test(s) cause the hang and fix them

## Task: Debug and Fix Hanging Tests

### Step 1: Identify Hanging Test(s)

Run the test file and identify exactly which subtest hangs:

```bash
perl -Ilib -e 'alarm 30; exec "perl", "-Ilib", "-v", "t/grey/static/04-concurrency/030-scheduled-executor.t"' 2>&1 | tail -50
```

The output will show which test starts but doesn't complete.

### Step 2: Analyze the Hanging Test

Once you identify the hanging test, examine it for these common issues:

1. **Infinite loop in ScheduledExecutor->run()**
   - Check if `has_callbacks || has_timers` condition can become false
   - Verify timers actually fire and get removed from wheel
   - Check if time advances properly

2. **Timers scheduled at current_time**
   - Timers at expiry == current_time will never fire
   - Verify all timers have expiry > current_time

3. **Callbacks that schedule more timers indefinitely**
   - Check if any callback creates new timers without a stop condition

4. **next_tick() + schedule_delayed() interaction**
   - Verify the mix of immediate and delayed callbacks works correctly

### Step 3: Common Fix Patterns

**If timers aren't firing:**
```perl
# Debug: Add to ScheduledExecutor->run()
say "Loop: callbacks=", !$self->is_done, " timers=", $wheel->timer_count,
    " time=", $current_time, " next=", ($wheel->find_next_timeout // "none");
```

**If time isn't advancing:**
- Check that `next_timeout > current_time` is true
- Verify `$current_time = $next_timeout` assignment happens
- Ensure wheel->advance_by() is called

**If timers aren't being removed:**
- Check that timers fire their events
- Verify timer_count decreases when timers fire
- Check the tracking hash is properly maintained

### Step 4: Fix and Verify

1. Fix the identified issue(s)
2. Run the specific hanging test in isolation to verify fix
3. Run the full test suite: `prove -l t/grey/static/04-concurrency/030-scheduled-executor.t`
4. Run all tests: `prove -lr t/` to ensure no regressions

## Key Implementation Details

### ScheduledExecutor Time Model
- `current_time` starts at 0
- `schedule_delayed(cb, delay)` enforces minimum delay of 1:
  ```perl
  my $actual_delay = $delay_ticks < 1 ? 1 : $delay_ticks;
  ```
- Timers must have `expiry > current_time` to fire

### Timer::Wheel Behavior
- `find_next_timeout()` returns minimum expiry among all timers (O(N))
- `advance_by(N)` fires all timers with expiry == state->time
- Timers are removed from tracking when fired (in check_timers)

### ScheduledExecutor->run() Logic
```perl
method run {
    while (!$self->is_done || $wheel->timer_count > 0) {
        my $next_timeout = $wheel->find_next_timeout;

        if (defined $next_timeout && $next_timeout > $current_time) {
            my $delta = $next_timeout - $current_time;
            $wheel->advance_by($delta);
            $current_time = $next_timeout;
        }

        $self->tick;  # Process callbacks added by timers

        last if $self->is_done && $wheel->timer_count == 0;
    }
}
```

## Expected Outcome

All 14 subtests in `t/grey/static/04-concurrency/030-scheduled-executor.t` should pass without hanging:

1. ✅ ScheduledExecutor construction
2. ✅ schedule_delayed basic functionality
3. ✅ current_time advances correctly
4. ✅ cancel scheduled callback
5. ✅ cancel non-existent timer
6. ✅ immediate callbacks (delay 0)
7. ⏳ callbacks can schedule more callbacks
8. ⏳ empty executor completes immediately
9. ⏳ multiple callbacks at same time
10. ⏳ large delay values
11. ⏳ schedule_delayed works with next_tick
12. ⏳ schedule_delayed returns unique IDs
13. ⏳ timer wheel accessible for debugging
14. ⏳ (test 14 name unknown)

## Files to Check

- `lib/grey/static/concurrency/util/ScheduledExecutor.pm` - Main implementation
- `lib/grey/static/time/wheel/Timer/Wheel.pm` - Timer wheel (find_next_timeout, check_timers)
- `t/grey/static/04-concurrency/030-scheduled-executor.t` - Test file

## Success Criteria

- All ScheduledExecutor tests pass: `prove -l t/grey/static/04-concurrency/030-scheduled-executor.t`
- No regressions in timer tests: `prove -l t/grey/static/07-time/`
- Full test suite passes: `prove -lr t/`

Once tests are fixed and passing, we can proceed with implementing Promise timeout support.
