# Cache Library Benchmark

This project benchmarks **LocalCache** against a range of Java caching libraries. It ships with a [JMH](https://openjdk.org/projects/code-tools/jmh/) harness plus automation that archives every run and generates a static dashboard (`index.html`) suitable for GitHub Pages.

---

## At a Glance

- **Benchmark suite**: `CacheBenchmark` exercises LocalCache alongside in-memory contenders (Caffeine, Guava) and MapDB across multiple dataset sizes and payload profiles.
- **Parameter sweeps**: Every benchmark runs across `dataSize ∈ {1K, 10K, 100K}` and value payloads `{10 lines, 100 lines, 1000 lines, 1 KB}`.
- **Automation**: `./benchmark.sh <dataSize> <payloadLines>` builds, executes, archives the raw results under `reports/<timestamp>/`, updates `reports/runs.json`, and regenerates `index.html`.
- **Visualization**: Open `index.html` locally or host it on GitHub Pages to browse historic runs, filter by dataset/profile, and download the raw JMH JSON.

---

## Prerequisites

- Java 17+
- Maven 3.8+
- Bash + Python 3 (for the publishing script)

---

## Running Benchmarks

### Quick Start: One-off JMH Invocation

```bash
# Build the shaded JMH JAR
mvn clean package

# Run the entire suite (interactive prompts list benchmarks)
java -jar target/benchmarks.jar

# Run a single benchmark with custom parameters
java -jar target/benchmarks.jar \
  CacheBenchmark.putLocalCache \
  -p dataSize=10000 -p valueProfile=BYTES_1024
```

Common JMH flags:
- `-wi <n>` warmup iterations (default 2)
- `-i <n>` measurement iterations (default 3)
- `-f <n>` forks (default 1)
- `-p key=value` set a parameter (repeatable)
- `-rf json -rff results.json` emit machine-readable output

### Automated Pipeline (Recommended)

```bash
./run-and-publish.sh <data_size> <value_profile>
```

Required arguments:

- `data_size`: `1`, `100`, `1000`, or `10000`
- `value_profile`: `LINES_1`, `LINES_10`, `LINES_100`, or `LINES_1000`

What the script does:
1. Rebuilds the JAR (`mvn clean package`).
2. Executes the benchmarks with the supplied data size/profile (warmup 0, measurement 1, fork 1) unless `JMH_ARGS` is provided to override the entire command line.
3. Streams the console log to `reports/<timestamp>/benchmark-output.log` and saves the raw JSON to `reports/<timestamp>/results.json`.
4. Generates a per-operation summary table (`reports/<timestamp>/summary.md`).
5. Updates `reports/runs.json` with metadata (label, parameters, counts).
6. Regenerates `index.html` so the dashboard reflects the newest run.

Each invocation creates a new timestamped folder, keeping historical data intact for publishing.

---

## Working with Results

- `index.html` – Interactive dashboard (run selector, filters, download links). Commit this file to publish.
- `reports/runs.json` – Catalog consumed by the dashboard. Contains metadata for every archived run.
- `reports/<timestamp>/results.json` – Raw JMH output (feed into https://jmh.morethan.io/ or other tooling).
- `reports/<timestamp>/benchmark-output.log` – Full console log (useful for troubleshooting).

To publish on GitHub Pages (or any static host), commit:
```
index.html
reports/runs.json
reports/<timestamp>/
```
and serve the repository. The dashboard loads JSON via relative paths, so no backend is required.

---

## Fair Benchmarking Guidance

When comparing LocalCache against other solutions, consider the following:

| Aspect | In-memory caches | Persistent stores |
|--------|------------------|-------------------|
| **Durability** | ❌ No | ✅ Yes |
| **Latency / Throughput** | ⚡⚡⚡⚡⚡ | ⚡⚡ |
| **Operational overhead** | Low | Medium (disk, fsync) |
| **Best for** | Hot caches, request dedupe | Large datasets, restart resilience |

### Persistent Suite Expectations
1. **Chronicle Map** – Off-heap and memory-mapped, usually the fastest durable option.
2. **H2 MVStore** – Log-structured store with MVCC, strong all-round performance.
3. **MapDB** – Memory-mapped, good balance of features.
4. **LocalCache** – Prioritises durability, TTL, and filesystem transparency; slower throughput.

### Choosing the Right Tool
- **Pick LocalCache** when you need filesystem-backed persistence, Redis-like semantics, TTL, and can tolerate < 100 ops/s.
- **Pick Caffeine / Guava** when maximum throughput matters and you can rebuild cache state on restart.
- **Pick Chronicle Map / H2 MVStore / MapDB** when you need durable storage with higher throughput than LocalCache.

---

## Extending the Benchmarks

- Add new libraries by registering them in `CacheBenchmark` and the Maven `pom.xml`.
- Introduce additional parameters (e.g. `threads`, `ttl`) via `@Param` annotations.
- Track new metrics by parsing `results.json` or adding custom reporters.
- Update `run-and-publish.sh` if you add extra artifacts (e.g. CSV exports) so they’re archived with each run.

---

## Repository Layout

```
├── pom.xml                         # Maven configuration with dependencies + shade plugin
├── src/main/java/com/benchmark/... # Benchmark suites
├── benchmark.sh                    # Automation script (build, run, archive, regenerate dashboard)
├── reports/
│   ├── runs.json                   # Catalog of archived runs
│   └── <timestamp>/
│       ├── results.json            # Raw JMH output
│       └── benchmark-output.log    # Console log
└── index.html                      # Static dashboard
```

---

## Contributing / Next Steps

- Record fresh data using `./benchmark.sh <dataSize> <payloadLines>` to capture the full parameter matrix.
- Compare multiple runs via the dashboard filters or by uploading `results.json` files to the JMH Visualizer.
- Extend the suite with additional caches or metrics (memory usage, recovery time) as needed.

Happy benchmarking!
