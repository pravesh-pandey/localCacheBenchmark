package com.benchmark.cache;

import com.github.benmanes.caffeine.cache.Caffeine;
import com.github.benmanes.caffeine.cache.Cache;
import com.google.common.cache.CacheBuilder;
import com.localcache.LocalCache;
import org.mapdb.DB;
import org.mapdb.DBMaker;
import org.mapdb.HTreeMap;
import org.openjdk.jmh.annotations.*;
import org.openjdk.jmh.infra.Blackhole;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.Duration;
import java.util.Comparator;
import java.util.concurrent.TimeUnit;

@State(Scope.Benchmark)
@BenchmarkMode(Mode.Throughput)
@OutputTimeUnit(TimeUnit.SECONDS)
@Warmup(iterations = 2, time = 1)
@Measurement(iterations = 3, time = 2)
@Fork(1)
public class CacheBenchmark {

    @Param({"1000", "10000"})
    private int dataSize;

    private LocalCache localCache;
    private Cache<String, String> caffeineCache;
    private com.google.common.cache.Cache<String, String> guavaCache;
    private HTreeMap<String, String> mapdbCache;
    private DB mapdb;

    private Path localCachePath;
    private Path mapdbPath;

    private String[] keys;
    private String[] values;

    @Setup(Level.Trial)
    public void setup() throws IOException {
        // Prepare test data
        keys = new String[dataSize];
        values = new String[dataSize];
        for (int i = 0; i < dataSize; i++) {
            keys[i] = "key_" + i;
            values[i] = "value_" + i + "_" + "x".repeat(100); // ~100 chars
        }

        // Setup LocalCache
        localCachePath = Files.createTempDirectory("localcache_bench");
        localCache = LocalCache.newBuilder(localCachePath)
                .hashAlgorithm("SHA-256")
                .shardSizes(2, 2)
                .cleanInterval(Duration.ofMinutes(10))
                .build();

        // Setup Caffeine
        caffeineCache = Caffeine.newBuilder()
                .maximumSize(dataSize * 2)
                .build();

        // Setup Guava
        guavaCache = CacheBuilder.newBuilder()
                .maximumSize(dataSize * 2)
                .build();

        // Setup MapDB
        Path tempDir = Files.createTempDirectory("mapdb_bench");
        mapdbPath = tempDir.resolve("cache.db");
        mapdb = DBMaker.fileDB(mapdbPath.toFile())
                .fileMmapEnable()
                .make();
        mapdbCache = mapdb.hashMap("cache", org.mapdb.Serializer.STRING, org.mapdb.Serializer.STRING).createOrOpen();

        // Pre-populate caches for read benchmarks
        for (int i = 0; i < dataSize; i++) {
            localCache.putString(keys[i], values[i]);
            caffeineCache.put(keys[i], values[i]);
            guavaCache.put(keys[i], values[i]);
            mapdbCache.put(keys[i], values[i]);
        }
        mapdb.commit();
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
    public void putCaffeine(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            caffeineCache.put(keys[i], values[i]);
        }
        bh.consume(caffeineCache);
    }

    @Benchmark
    public void putGuava(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            guavaCache.put(keys[i], values[i]);
        }
        bh.consume(guavaCache);
    }

    @Benchmark
    public void putMapDB(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            mapdbCache.put(keys[i], values[i]);
        }
        mapdb.commit();
        bh.consume(mapdbCache);
    }

    // ========== READ BENCHMARKS ==========

    @Benchmark
    public void getLocalCache(Blackhole bh) throws IOException {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(localCache.getString(keys[i]).orElse(null));
        }
    }

    @Benchmark
    public void getCaffeine(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(caffeineCache.getIfPresent(keys[i]));
        }
    }

    @Benchmark
    public void getGuava(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(guavaCache.getIfPresent(keys[i]));
        }
    }

    @Benchmark
    public void getMapDB(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            bh.consume(mapdbCache.get(keys[i]));
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
    public void mixedCaffeine(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            if (i % 5 == 0) {
                caffeineCache.put(keys[i], values[i]);
            } else {
                bh.consume(caffeineCache.getIfPresent(keys[i]));
            }
        }
    }

    @Benchmark
    public void mixedGuava(Blackhole bh) {
        for (int i = 0; i < dataSize; i++) {
            if (i % 5 == 0) {
                guavaCache.put(keys[i], values[i]);
            } else {
                bh.consume(guavaCache.getIfPresent(keys[i]));
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
}
