# Test Audit Deep Dive - Find and Fix All Issues

## Objective

Perform a comprehensive audit of the entire test suite to:
1. Find ALL skipped tests, TODO tests, and commented-out tests
2. Understand WHY each test is skipped/incomplete
3. Either FIX the issue or DOCUMENT why it can't/shouldn't be fixed
4. Surface any hidden limitations or bugs in the implementation
5. Ensure test suite is rigorous and complete

## Instructions

### Phase 1: Discovery

**Task:** Find all problematic tests across the entire codebase.

Search for:
- `SKIP` blocks (uppercase)
- `skip` function calls (Test::More)
- `TODO` blocks
- `todo_skip` function calls
- Comments like `# TODO`, `# FIXME`, `# XXX`, `# SKIP`
- Commented-out test code (large blocks of `#` comments)
- `plan skip_all => ...`

**Search commands:**
```bash
# Find SKIP blocks
grep -rn "SKIP:\|skip\|TODO\|todo_skip\|FIXME\|XXX" t/ --include="*.t"

# Find commented test code (multiple # lines in a row)
grep -rn "^[[:space:]]*#.*test\|^[[:space:]]*#.*ok\|^[[:space:]]*#.*is" t/ --include="*.t"

# Find skip_all
grep -rn "skip_all" t/ --include="*.t"
```

**Output:** Create a comprehensive list with:
- File path
- Line number
- Type (SKIP, TODO, commented, etc.)
- Reason given (if any)
- Context (what's being tested)

### Phase 2: Investigation

For EACH issue found:

1. **Understand the Test**
   - What functionality is being tested?
   - Why was it skipped/disabled?
   - Is the reason still valid?

2. **Check Implementation**
   - Does the feature exist?
   - Does it work?
   - Is there a bug preventing the test from passing?

3. **Categorize the Issue**
   - Bug in implementation (needs fixing)
   - Missing feature (decide: implement or document as limitation)
   - Test is wrong (fix the test)
   - Legitimately should be skipped (document why)
   - Historical artifact (remove if no longer relevant)

### Phase 3: Resolution

For each issue, choose ONE action:

**Option A: FIX IT**
- Fix the bug in implementation
- Implement the missing feature
- Fix the incorrect test
- Remove the SKIP/TODO and verify test passes

**Option B: DOCUMENT IT**
- Add clear comment explaining WHY it's skipped
- Document the limitation in module POD
- Add to TODO.md with priority and reasoning
- Consider adding a warning in user-facing documentation

**Option C: REMOVE IT**
- If test is obsolete/no longer relevant
- If testing removed functionality
- If duplicates another test
- Document what was removed and why

### Phase 4: Testing

After each fix:
1. Run the specific test file
2. Run related tests
3. Run full test suite to catch regressions
4. Verify no new issues introduced

### Phase 5: Documentation

Create or update:

**TEST_AUDIT_RESULTS.md** with:
- Summary of issues found
- What was fixed
- What was documented as limitation
- What was removed
- Remaining known issues with justification

**Update TODO.md** with any deferred work

**Update module POD** with documented limitations

## Expected Outputs

### 1. Clean Test Suite
- All tests either pass or have clear documented reason for skip
- No hidden/uncommented failing tests
- No mystery TODO blocks

### 2. Documentation
- TEST_AUDIT_RESULTS.md (comprehensive report)
- Updated TODO.md (any deferred fixes)
- Updated module POD (documented limitations)

### 3. Known Issues List
- Clear list of what doesn't work and why
- Priority assigned to each
- Decision on whether to fix or accept

## Specific Areas to Scrutinize

### Promise (t/grey/static/04-concurrency/0*-promise*.t)
- Nested promise flattening (known SKIP)
- Error propagation in chains
- Edge cases in timeout/delay
- Memory leaks in circular references

### Flow (t/grey/static/04-concurrency/0*-*flow*.t)
- Backpressure edge cases
- Error propagation through operations
- Completion handling
- Cancellation behavior
- Executor chaining issues

### Stream (t/grey/static/02-stream/*.t)
- Operation edge cases
- Empty stream handling
- Infinite stream termination
- Time operations with edge cases
- recurse() operation (known issues mentioned in docs)

### ScheduledExecutor (t/grey/static/04-concurrency/030-*.t)
- Timer cancellation edge cases
- Concurrent timer modifications
- Time advancement accuracy
- Memory leaks with many timers

### IO Streams (t/grey/static/03-io-stream/*.t)
- File handling edge cases
- Error conditions
- Large file handling
- Directory operations

## Success Criteria

✅ All SKIP/TODO blocks have clear documentation
✅ All fixable bugs are fixed
✅ All limitations are documented in POD
✅ Test suite runs clean (no surprises)
✅ TEST_AUDIT_RESULTS.md provides complete picture
✅ Team knows exactly what works and what doesn't

## Anti-Patterns to Avoid

❌ Don't skip tests just because they're hard to fix
❌ Don't leave vague comments ("TODO: fix this later")
❌ Don't ignore edge cases
❌ Don't assume implementation is correct if test is wrong
❌ Don't remove tests without understanding why they existed

## Example Resolution

**Before:**
```perl
SKIP: {
    skip 'Deeply nested promise flattening not yet implemented', 1;
    # test code...
}
```

**After (Option 1 - Fixed):**
```perl
# Test deeply nested promise flattening
subtest 'deeply nested promises are flattened' => sub {
    # Fixed implementation, test now passes
    # ...
};
```

**After (Option 2 - Documented Limitation):**
```perl
SKIP: {
    skip 'Deeply nested promise flattening (3+ levels) not supported - edge case', 1;
    # This is a limitation of the current Promise implementation.
    # Nested promises beyond 2 levels require recursive flattening
    # which adds significant complexity for minimal benefit.
    # See Promise.pm POD section "LIMITATIONS" for details.
    # Tracked in TODO.md as low-priority enhancement.
    # ...
}
```

## Timeline

- **Phase 1 (Discovery):** 30 minutes - comprehensive search
- **Phase 2 (Investigation):** 1-2 hours - understand each issue
- **Phase 3 (Resolution):** 2-4 hours - fix or document
- **Phase 4 (Testing):** 30 minutes - verify fixes
- **Phase 5 (Documentation):** 30 minutes - write report

**Total: 4-8 hours** for thorough audit

## Notes

- Be thorough but pragmatic
- Some limitations are acceptable if documented
- Fix real bugs, document design decisions
- Aim for transparency, not perfection
- When in doubt, document and defer to TODO.md

---

**Ready to start? Begin with Phase 1: Discovery**
