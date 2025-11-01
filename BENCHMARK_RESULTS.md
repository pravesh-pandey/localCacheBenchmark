# LocalCache Benchmark Results

## Executive Summary

Comprehensive performance comparison of LocalCache against popular Java caching libraries: Caffeine, Guava Cache, and MapDB.

## Test Environment
- **JVM**: OpenJDK 17.0.16
- **Hardware**: Linux x86_64
- **Date**: November 1, 2025
- **Benchmark Tool**: JMH 1.37
- **Test Sizes**: 1,000 and 10,000 entries
- **Value Size**: ~100 characters per entry

## Libraries Tested

1. **LocalCache (0.1.0)** - Filesystem-backed cache with TTL support
2. **Caffeine (3.1.8)** - High-performance in-memory cache
3. **Guava Cache (32.1.3-jre)** - Google's in-memory caching library
4. **MapDB (3.1.0)** - Disk-based key-value store

## Benchmark Results

### READ Performance (ops/second)

| Library | 1,000 entries | 10,000 entries | Performance vs LocalCache (1K) |
|---------|--------------|----------------|--------------------------------|
| **Caffeine** | 82,858 | 7,479 | **1,478x faster** |
| **Guava** | 22,866 | 2,327 | **408x faster** |
| **MapDB** | 3,403 | 316 | **61x faster** |
| **LocalCache** | 56 | 5.2 | *baseline* |

### WRITE Performance (ops/second)

| Library | 1,000 entries | 10,000 entries | Performance vs LocalCache (1K) |
|---------|--------------|----------------|--------------------------------|
| **Caffeine** | 37,146 | 3,441 | **83,293x faster** |
| **Guava** | 17,836 | 1,983 | **39,987x faster** |
| **MapDB** | 409 | 127 | **917x faster** |
| **LocalCache** | 0.446 | 0.045 | *baseline* |

### MIXED Workload (80% read, 20% write) (ops/second)

| Library | 1,000 entries | 10,000 entries | Performance vs LocalCache (1K) |
|---------|--------------|----------------|--------------------------------|
| **Caffeine** | 67,238 | 5,778 | **31,401x faster** |
| **Guava** | 21,249 | 2,264 | **9,923x faster** |
| **MapDB** | 426 | 134 | **199x faster** |
| **LocalCache** | 2.14 | 0.213 | *baseline* |

## Key Findings

### Performance Ranking

**Best to Worst Performance:**
1. **Caffeine** - Consistently the fastest across all operations (in-memory)
2. **Guava Cache** - Strong performance, about 3-4x slower than Caffeine (in-memory)
3. **MapDB** - Moderate performance for disk-based storage
4. **LocalCache** - Slowest performance due to filesystem operations

### Performance Analysis

#### Caffeine (Winner)
- **Strengths**: Exceptional performance due to pure in-memory operations
- **Read**: 1,478x faster than LocalCache
- **Write**: 83,293x faster than LocalCache
- **Use Case**: High-performance caching where data loss on restart is acceptable

#### Guava Cache
- **Strengths**: Solid performance, well-tested, stable API
- **Read**: 408x faster than LocalCache
- **Write**: 39,987x faster than LocalCache
- **Use Case**: General-purpose in-memory caching

#### MapDB
- **Strengths**: Disk persistence with reasonable performance
- **Read**: 61x faster than LocalCache
- **Write**: 917x faster than LocalCache
- **Use Case**: Disk-backed storage with good read performance

#### LocalCache
- **Strengths**: Redis-like API, filesystem persistence, TTL support
- **Weakness**: Significantly slower due to filesystem I/O on every operation
- **Performance Impact**:
  - Reads: 56-1,478x slower than competition
  - Writes: 917-83,293x slower than competition
- **Use Case**: When filesystem persistence and Redis-like semantics are required, and performance is not critical

## Scaling Behavior

### 1K → 10K entries performance degradation:

| Library | Read Degradation | Write Degradation | Mixed Degradation |
|---------|-----------------|-------------------|-------------------|
| **Caffeine** | 11.1x | 10.8x | 11.6x |
| **Guava** | 9.8x | 9.0x | 9.4x |
| **MapDB** | 10.8x | 3.2x | 3.2x |
| **LocalCache** | 10.8x | 9.9x | 10.0x |

All libraries show similar 10x degradation when scaling from 1K to 10K entries, except MapDB which shows better write scaling (only 3.2x degradation).

## Recommendations

### Use LocalCache when:
- You need filesystem-backed persistence that survives process restarts
- You want Redis-like API ergonomics
- Performance is not a critical concern (< 100 ops/sec is acceptable)
- Data durability is more important than speed

### Use Caffeine when:
- Maximum performance is required
- In-memory caching is acceptable
- You need advanced features (time-based eviction, size-based eviction, etc.)

### Use Guava Cache when:
- You want solid performance with a stable, well-known API
- You're already using Guava in your project
- In-memory caching is acceptable

### Use MapDB when:
- You need disk persistence
- Performance requirements are moderate (hundreds of ops/sec)
- You need a key-value store with better performance than LocalCache

## Conclusion

LocalCache prioritizes **durability and API ergonomics** over raw performance. With filesystem I/O on every operation, it's 61-83,000x slower than alternatives depending on the workload.

**Performance Trade-off**: LocalCache exchanges speed for durability. Every read/write involves disk I/O, making it suitable for:
- Configuration caches (low frequency access)
- Persistent session storage (durability critical)
- Application state that must survive restarts

**Not suitable for**:
- High-throughput caching
- Frequently accessed data
- Performance-critical paths
- Hot data caching

For high-performance scenarios, use **Caffeine** or **Guava**. For disk persistence with better performance, use **MapDB**. Use **LocalCache** when you specifically need filesystem-backed storage with Redis-like semantics and can accept the performance trade-off.

## Raw Data

Full benchmark results available in:
- `results.json` - Machine-readable JMH output
- `benchmark-output.log` - Complete benchmark run log
