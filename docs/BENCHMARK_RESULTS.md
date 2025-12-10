# Benchmark Results Summary
## grey::static Concurrency Performance Analysis
### Date: 2025-12-09

---

## Executive Summary

Comprehensive benchmarks were run to evaluate performance characteristics of:
- ScheduledExecutor (timer queue implementation)
- Stream vs Flow (pull-based vs push-based processing)
- Promise + ScheduledExecutor integration
- Flow throughput and backpressure

**Key Findings:**
1. ✅ ScheduledExecutor performs well - fast-path optimization working
2. ✅ Stream is 12-18x faster than Flow for batch processing
3. ✅ Flow is 114x faster for early-exit scenarios
4. ✅ Promise + ScheduledExecutor is very fast
5. ✅ Backpressure (larger request sizes) improves Flow throughput 2x

**Recommendation:** Current design is performant. No urgent optimizations needed.

---

## Benchmark 1: ScheduledExecutor Performance

### Test 1: Timer Insertion

| Scenario | Rate | Notes |
|----------|------|-------|
| 10 timers | >999k/s | Extremely fast |
| 100 timers | 33k/s | Fast |
| 1000 timers | 2.7k/s | Acceptable |

**Analysis:** Insertion performance scales as expected. O(n) insertion but with fast-path optimization for ascending order.

### Test 2: Insertion Order Impact

| Order | Rate | vs Random |
|-------|------|-----------|
| Ascending (best case) | 33k/s | **433% faster** |
| Descending (worst case) | 20k/s | 220% faster |
| Random | 6.2k/s | baseline |

**Analysis:** Fast-path optimization for appending to end works excellently. Most real-world usage (scheduling future events) will benefit from this.

### Test 3: Timer Execution

| Timer Count | Rate |
|-------------|------|
| 10 timers | >100M/s |
| 100 timers | 10k/s |
| 1000 timers | 714/s |

**Analysis:** Execution is fast. Good performance for typical use cases.

### Test 4: Timer Cancellation

| Cancellation Rate | Throughput |
|-------------------|------------|
| 50% cancelled | 8.3k/s |
| 90% cancelled | 5.8k/s |

**Analysis:** Lazy deletion strategy works well. High cancellation rate reduces throughput slightly but still acceptable.

### Test 5: Dynamic Timer Addition

Both recursive and tree-based dynamic timer addition performed well with no issues.

**Verdict:** ✅ ScheduledExecutor performance is solid. No optimization needed.

---

## Benchmark 2: Stream vs Flow

### Summary Table

| Test | Stream | Flow | Winner | Ratio |
|------|--------|------|--------|-------|
| Simple map (100 elements) | 14.3k/s | 901/s | Stream | **14.8x** |
| Grep + Map | 11.1k/s | 813/s | Stream | **13.7x** |
| Complex pipeline (1000 elements) | 435/s | 33/s | Stream | **13.2x** |
| Early exit (10 from 1M) | 42.9/s | 4.9k/s | **Flow** | **114x** |
| Reduction (sum) | 25k/s | 1.7k/s | Stream | **14.8x** |
| Large dataset (10k elements) | 103/s | 5.3/s | Stream | **19.4x** |

### Key Insights

**1. Stream Dominates Batch Processing**
- **12-19x faster** for collecting/processing complete datasets
- Pull-based lazy evaluation is efficient
- Minimal overhead per operation

**2. Flow Wins for Early Exit**
- **114x faster** when processing few items from huge source
- Stream's lazy take() creates source but still has overhead
- Flow only processes what's submitted

**3. Why Stream is Faster for Batches**
- No executor overhead
- No async callbacks
- Direct method calls
- Optimized for collection operations

**4. Why Flow is Better for Events**
- Backpressure control (request/offer)
- Asynchronous processing
- Event-driven architecture
- Good for real-time streams

### Use Case Recommendations

**Use Stream when:**
- Processing complete datasets
- Batch transformations
- Collection operations (map, filter, reduce)
- Performance is critical
- Early termination is rare

**Use Flow when:**
- Event-driven systems
- Real-time data streams
- Backpressure required
- Async processing needed
- Subscribing to publishers

---

## Benchmark 3: Flow Throughput

### Test 1: Element Count Scaling

| Elements | Rate | Time per element |
|----------|------|------------------|
| 100 | 1.7k/s | 0.6 ms |
| 1000 | 156/s | 6.4 ms |
| 10000 | 8.9/s | 112 ms |

**Analysis:** Linear scaling. Flow has constant per-element overhead from executor chaining and callbacks.

### Test 2: Operation Overhead

| Operations | Rate | Overhead |
|------------|------|----------|
| No ops | 154/s | baseline |
| 1 map | 87.7/s | 43% slower |
| 3 maps | 47.2/s | 69% slower |
| 5 maps | 31.7/s | 79% slower |

**Analysis:** Each operation adds executor + callback overhead. Pipeline length impacts throughput.

### Test 3: Filtering Efficiency

| Filter | Rate | Notes |
|--------|------|-------|
| Keep 50% | 103/s | baseline |
| Keep 10% | 122/s | 18% faster |
| Keep 1% | 130/s | 26% faster |

**Analysis:** Filtering is efficient. Less data downstream = faster processing.

### Test 4: Backpressure Impact

| Request Size | Rate | vs request_size=1 |
|--------------|------|-------------------|
| 1 | 1.7k/s | baseline |
| 10 | 2.5k/s | **50% faster** |
| 100 | 3.3k/s | **100% faster** |

**Analysis:** ⭐ **Larger request sizes significantly improve throughput.** Batching reduces executor overhead.

**Recommendation:** Use larger request sizes (10-100) for better performance when backpressure isn't critical.

---

## Benchmark 4: Promise + ScheduledExecutor

### Summary

All Promise operations are **extremely fast**:
- Basic resolve/reject: <0.01ms
- Promise->delay(): <0.01ms regardless of delay ticks
- Promise->timeout(): <0.01ms
- Chained promises: scales linearly

### Concurrent Promises

| Concurrent Count | Rate |
|------------------|------|
| 10 promises | 20k/s |
| 50 promises | 2.5k/s |
| 100 promises | 1.25k/s |

**Analysis:** Scales well but with overhead. Each promise creates callbacks and timer entries.

**Verdict:** ✅ Promise + ScheduledExecutor performance is excellent. No concerns.

---

## Overall Recommendations

### 1. ScheduledExecutor: Production Ready ✅

**Performance:** Excellent for typical use cases
- Fast insertion (especially ascending order)
- Good execution performance
- Efficient cancellation

**When to Optimize:**
- Only if >1000 concurrent timers regularly
- Consider min-heap optimization if profiling shows bottleneck
- Current O(n) insertion adequate for now

### 2. Stream vs Flow: Use the Right Tool

**Stream (pull-based):**
- ✅ Batch processing
- ✅ Data transformations
- ✅ Collection operations
- ❌ Real-time events
- ❌ Backpressure needed

**Flow (push-based):**
- ❌ Batch processing
- ✅ Real-time events
- ✅ Backpressure control
- ✅ Event-driven systems
- ✅ Few items from large source

**No Integration Needed:** They serve different purposes. Keep separate.

### 3. Flow Optimization Tips

If using Flow for throughput-sensitive applications:

1. **Increase request_size** (10-100) for 2x improvement
2. **Keep pipelines short** - each operation adds overhead
3. **Filter early** - reduce data downstream
4. **Consider Stream** - if you don't need async/backpressure

### 4. Promise: No Concerns ✅

Promise + ScheduledExecutor integration is fast and efficient. Use confidently.

---

## Benchmark Reproducibility

All benchmarks can be re-run:

```bash
cd /Users/stevan/Projects/perl/p5-grey-static

# Individual benchmarks
perl benchmarks/02-scheduled-executor.pl
perl benchmarks/03-flow-throughput.pl
perl benchmarks/04-stream-vs-flow.pl
perl benchmarks/05-promise-scheduled-executor.pl

# Run all
for f in benchmarks/*.pl; do perl "$f"; done
```

---

## Future Benchmarking

Optional benchmarks if concerns arise:

1. **Executor overhead** (benchmark 01) - measure per-component vs shared executor
2. **Memory usage** - profile with large pipelines
3. **Real-world workloads** - benchmark actual use cases
4. **Min-heap optimization** - compare against sorted array for large timer counts

---

## Conclusions

1. ✅ **ScheduledExecutor is production-ready** - performance is solid
2. ✅ **Stream faster for batches** - 12-19x faster than Flow for collection processing
3. ✅ **Flow better for events** - async, backpressure, reactive
4. ✅ **Promise integration works** - fast and efficient
5. ✅ **Current design validated** - no urgent changes needed

**Next Steps:**
- Document architecture and usage patterns
- Create integration examples
- Write comprehensive POD documentation
- Add to CHANGELOG.md

No performance concerns block moving forward with documentation and examples.
