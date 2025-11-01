package com.benchmark.cache;

import com.localcache.LocalCache;
import net.openhft.chronicle.map.ChronicleMap;
import org.h2.mvstore.MVMap;
import org.h2.mvstore.MVStore;
import org.mapdb.DB;
import org.mapdb.DBMaker;
import org.mapdb.HTreeMap;
import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;

import java.io.File;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Comparator;
import java.util.concurrent.TimeUnit;

/**
 * Fair benchmark comparing PERSISTENT/DISK-BASED cache implementations.
 * All libraries tested here support data persistence and survival across restarts.
 */
@State(Scope.Benchmark)
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@Warmup(iterations = 2, time = 1)
@Measurement(iterations = 3, time = 2)
@Fork(1)
public class PersistentCacheBenchmark {

    @Param({"1000", "10000", "100000"})
    private int dataSize;

    @Param({"LINES_10", "LINES_100", "LINES_1000", "BYTES_1024"})
    private ValueProfile valueProfile;

    // Persistent caches
    private LocalCache localCache;
    private HTreeMap<String, String> mapdbCache;
    private ChronicleMap<String, String> chronicleCache;
    private MVMap<String, String> h2mvCache;

    // Storage backends
    private DB mapdb;
    private MVStore h2mvStore;

    // Paths
    private Path localCachePath;
    private Path mapdbPath;
    private File chroniclePath;
    private Path h2mvPath;

    private String[] keys;
    private String[] values;

    @Setup(Level.Trial)
    public void setup() throws IOException {
        // Prepare test data
        keys = new String[dataSize];
        values = new String[dataSize];
        for (int i = 0; i < dataSize; i++) {
            keys[i] = "key_" + i;
            values[i] = valueProfile.valueForIndex(i);
        }

        // Setup LocalCache (filesystem-backed)
        localCachePath = Files.createTempDirectory("localcache_bench");
        localCache = LocalCache.newBuilder(localCachePath)
                .hashAlgorithm("SHA-256")
                .shardSizes(2, 2)
                .cleanInterval(Duration.ofMinutes(10))
                .build();

        // Setup MapDB (memory-mapped file)
        Path mapdbDir = Files.createTempDirectory("mapdb_bench");
        mapdbPath = mapdbDir.resolve("cache.db");
        mapdb = DBMaker.fileDB(mapdbPath.toFile())
                .fileMmapEnable()
                .make();
        mapdbCache = mapdb.hashMap("cache", org.mapdb.Serializer.STRING, org.mapdb.Serializer.STRING).createOrOpen();

        // Setup Chronicle Map (off-heap persistent)
        chroniclePath = Files.createTempFile("chronicle_bench", ".dat").toFile();
        chronicleCache = ChronicleMap
                .of(String.class, String.class)
                .name("benchmark-cache")
                .entries(dataSize)
                .averageKeySize(10)
                .averageValueSize(valueProfile.estimatedSize())
                .createPersistedTo(chroniclePath);

        // Setup H2 MVStore (embedded database storage)
        h2mvPath = Files.createTempFile("h2mv_bench", ".db");
        h2mvStore = new MVStore.Builder()
                .fileName(h2mvPath.toString())
                .open();
        h2mvCache = h2mvStore.openMap("cache");

        // Pre-populate caches for read benchmarks
        for (int i = 0; i < dataSize; i++) {
            localCache.putString(keys[i], values[i]);
            mapdbCache.put(keys[i], values[i]);
            chronicleCache.put(keys[i], values[i]);
            h2mvCache.put(keys[i], values[i]);
        }
        mapdb.commit();
        h2mvStore.commit();
    }

    @TearDown(Level.Trial)
    public void teardown() throws IOException {
        // Cleanup LocalCache
        if (localCache != null) {
            localCache.close();
        }
        if (localCachePath != null && Files.exists(localCachePath)) {
            Files.walk(localCachePath)
                    .sorted(Comparator.reverseOrder())
                    .forEach(path -> {
                        try {
                            Files.delete(path);
                        } catch (IOException e) {
                            // ignore
                        }
                    });
        }

        // Cleanup MapDB
        if (mapdb != null) {
            mapdb.close();
        }
        if (mapdbPath != null && Files.exists(mapdbPath)) {
            Path mapdbDir = mapdbPath.getParent();
            Files.walk(mapdbDir)
                    .sorted(Comparator.reverseOrder())
                    .forEach(path -> {
                        try {
                            Files.delete(path);
                        } catch (IOException e) {
                            // ignore
                        }
                    });
        }

        // Cleanup Chronicle Map
        if (chronicleCache != null) {
            chronicleCache.close();
        }
        if (chroniclePath != null && chroniclePath.exists()) {
            chroniclePath.delete();
        }

        // Cleanup H2 MVStore
        if (h2mvStore != null) {
            h2mvStore.close();
        }
        if (h2mvPath != null && Files.exists(h2mvPath)) {
            Files.delete(h2mvPath);
        }
    }

    // ========== WRITE BENCHMARKS ==========

    @Benchmark
    public void putLocalCache(Blackhole bh) throws IOException {
        for (int i = 0; i < dataSize; i++) {
            localCache.putString(keys[i], values[i]);
        }
        bh.consume(localCache);
    }

    @Benchmark
    public void putMapDB(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            mapdbCache.put(keys[i], values[i]);
        }
        mapdb.commit();
        bh.consume(mapdbCache);
    }

    @Benchmark
    public void putChronicleMap(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            chronicleCache.put(keys[i], values[i]);
        }
        bh.consume(chronicleCache);
    }

    @Benchmark
    public void putH2MVStore(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            h2mvCache.put(keys[i], values[i]);
        }
        h2mvStore.commit();
        bh.consume(h2mvCache);
    }

    // ========== READ BENCHMARKS ==========

    @Benchmark
    public void getLocalCache(Blackhole bh) throws IOException {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(localCache.getString(keys[i]).orElse(null));
        }
    }

    @Benchmark
    public void getMapDB(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(mapdbCache.get(keys[i]));
        }
    }

    @Benchmark
    public void getChronicleMap(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(chronicleCache.get(keys[i]));
        }
    }

    @Benchmark
    public void getH2MVStore(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(h2mvCache.get(keys[i]));
        }
    }

    // ========== MIXED READ/WRITE BENCHMARKS (80% reads, 20% writes) ==========

    @Benchmark
    public void mixedLocalCache(Blackhole bh) throws IOException {
        for (int i = 0; i < dataSize; i++) {
            if (i % 5 == 0) {
                localCache.putString(keys[i], values[i]);
            } else {
                bh.consume(localCache.getString(keys[i]).orElse(null));
            }
        }
    }

    @Benchmark
    public void mixedMapDB(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            if (i % 5 == 0) {
                mapdbCache.put(keys[i], values[i]);
            } else {
                bh.consume(mapdbCache.get(keys[i]));
            }
        }
        mapdb.commit();
    }

    @Benchmark
    public void mixedChronicleMap(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            if (i % 5 == 0) {
                chronicleCache.put(keys[i], values[i]);
            } else {
                bh.consume(chronicleCache.get(keys[i]));
            }
        }
    }

    @Benchmark
    public void mixedH2MVStore(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            if (i % 5 == 0) {
                h2mvCache.put(keys[i], values[i]);
            } else {
                bh.consume(h2mvCache.get(keys[i]));
            }
        }
        h2mvStore.commit();
    }
}
