# Cache Library Benchmark

Comprehensive benchmark comparing LocalCache with other popular Java caching libraries.

## Libraries Tested

1. **LocalCache (0.1.0)** - Filesystem-backed cache with O(1) lookups, TTL support, and Redis-like API
2. **Caffeine (3.1.8)** - High-performance in-memory cache
3. **Guava Cache (32.1.3)** - Google's in-memory caching library
4. **Ehcache (3.10.8)** - Versatile caching solution (configured for in-memory)
5. **MapDB (3.1.0)** - Disk-based key-value store with memory mapping

## Benchmark Tests

### Write Performance (put operations)
- Sequential writes of key-value pairs
- Tests raw write throughput

### Read Performance (get operations)
- Sequential reads from pre-populated cache
- Tests raw read throughput

### Mixed Workload (80% reads, 20% writes)
- Simulates realistic application usage
- Tests combined read/write performance

## Data Sizes

- 1,000 entries
- 10,000 entries
- Each value is approximately 100 characters

## Running the Benchmark

```bash
# Build the benchmark
mvn clean package

# Run all benchmarks
java -jar target/benchmarks.jar

# Run specific benchmark
java -jar target/benchmarks.jar CacheBenchmark.putLocalCache

# Run with custom parameters
java -jar target/benchmarks.jar -p dataSize=5000
```

## Interpreting Results

- **Throughput**: Operations per second (higher is better)
- **Mode**: Throughput mode measures how many operations complete per second
- **Score**: Average throughput across measurement iterations
- **Error**: Margin of error (99.9% confidence interval)

## Key Differences

- **LocalCache**: Disk-based persistence, survives restarts
- **Caffeine/Guava**: Pure in-memory, fastest but no persistence
- **Ehcache**: Configurable for both memory and disk
- **MapDB**: Memory-mapped files for disk persistence
