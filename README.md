# Cache Library Benchmark

This project benchmarks **LocalCache** against a range of Java caching and persistent-store libraries. It contains two complementary benchmark suites built with [JMH](https://openjdk.org/projects/code-tools/jmh/), plus automation that archives every run and generates a static dashboard (`index.html`) suitable for GitHub Pages.

---

## At a Glance

- **Benchmark suites**
  - `CacheBenchmark`: LocalCache vs. in-memory caches (Caffeine, Guava) and MapDB for small/medium datasets.
  - `PersistentCacheBenchmark`: LocalCache vs. disk-first stores (MapDB, Chronicle Map, H2 MVStore) for a fair persistence comparison.
- **Parameter sweeps**: Every benchmark runs across `dataSize ∈ {1K, 10K, 100K}` and value payloads `{10 lines, 100 lines, 1000 lines, 1 KB}`.
- **Automation**: `./run-and-publish.sh` builds, executes, archives the raw results under `reports/<timestamp>/`, updates `reports/runs.json`, and regenerates `index.html`.
- **Visualization**: Open `index.html` locally or host it on GitHub Pages to browse historic runs, filter by dataset/profile, and download the raw JMH JSON.

---

## Why Two Benchmark Suites?

| Suite | Libraries | Purpose |
|-------|-----------|---------|
| `CacheBenchmark` | LocalCache, Caffeine, Guava, MapDB | Highlights the trade-off between in-memory speed and LocalCache’s disk-backed durability. |
| `PersistentCacheBenchmark` | LocalCache, MapDB, Chronicle Map, H2 MVStore | Fair “apples-to-apples” comparison among persistent stores that survive restarts. |

### Key Takeaways from Recent Runs

*(Open `index.html` for the complete dataset – values below are indicative for `dataSize=1K`, `valueProfile=LINES_10`)*  

**Read Throughput (ops/s)**

| Library | CacheBenchmark | PersistentCacheBenchmark |
|---------|----------------|--------------------------|
| LocalCache | 54 | 53 |
| Caffeine | 52,503 | — |
| Guava Cache | 35,884 | — |
| MapDB | 1,677 | 1,943 |
| Chronicle Map | — | 995 |
| H2 MVStore | — | 20,637 |

**Write Throughput (ops/s)**

| Library | CacheBenchmark | PersistentCacheBenchmark |
|---------|----------------|--------------------------|
| LocalCache | 0.46 | 0.47 |
| Caffeine | 36,214 | — |
| Guava Cache | 29,155 | — |
| MapDB | 283 | 276 |
| Chronicle Map | — | 518 |
| H2 MVStore | — | 1,081 |

**Interpretation**
- In-memory caches (Caffeine, Guava) are orders of magnitude faster but lose data on restart.
- Among persistent stores, Chronicle Map and H2 MVStore generally outperform LocalCache; MapDB sits in between.
- LocalCache optimises for filesystem transparency, TTL support, and Redis-like ergonomics rather than throughput.

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
# Optional: override JMH arguments (e.g. quick smoke run)
export JMH_ARGS="-wi 0 -i 1 -f 1 -p dataSize=1000 -p valueProfile=LINES_10"

./run-and-publish.sh
```

What the script does:
1. Rebuilds the JAR (`mvn clean package`).
2. Runs JMH with the supplied parameters, streaming the console log to `reports/<timestamp>/benchmark-output.log`.
3. Saves the raw JSON to `reports/<timestamp>/results.json`.
4. Updates `reports/runs.json` with metadata (label, parameters, counts).
5. Regenerates `index.html` so the dashboard reflects the newest run.

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

- Add new libraries by registering them in `CacheBenchmark` or `PersistentCacheBenchmark` and the Maven `pom.xml`.
- Introduce additional parameters (e.g. `threads`, `ttl`) via `@Param` annotations.
- Track new metrics by parsing `results.json` or adding custom reporters.
- Update `run-and-publish.sh` if you add extra artifacts (e.g. CSV exports) so they’re archived with each run.

---

## Repository Layout

```
├── pom.xml                         # Maven configuration with dependencies + shade plugin
├── src/main/java/com/benchmark/... # Benchmark suites
├── run-and-publish.sh              # Automation script (build, run, archive, regenerate dashboard)
├── reports/
│   ├── runs.json                   # Catalog of archived runs
│   └── <timestamp>/
│       ├── results.json            # Raw JMH output
│       └── benchmark-output.log    # Console log
└── index.html                      # Static dashboard
```

---

## Contributing / Next Steps

- Record fresh data using `./run-and-publish.sh` without `JMH_ARGS` to capture the full parameter matrix.
- Compare multiple runs via the dashboard filters or by uploading `results.json` files to the JMH Visualizer.
- Extend the fair persistent comparison with additional metrics (memory usage, recovery time) if needed.

Happy benchmarking!
