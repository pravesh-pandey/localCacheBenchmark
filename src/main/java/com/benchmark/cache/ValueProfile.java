package com.benchmark.cache;

import java.util.Arrays;

/**
 * Defines the payload profiles used when generating cache values for benchmarks.
 * Each profile produces a deterministic base string so benchmarks can scale
 * value sizes without introducing randomness between iterations.
 */
public enum ValueProfile {
    LINES_10(ValueType.LINES, 10),
    LINES_100(ValueType.LINES, 100),
    LINES_1000(ValueType.LINES, 1000),
    BYTES_1024(ValueType.BYTES, 1024);

    private static final String LINE_TEMPLATE = "benchmark-value-line-%04d";

    private final ValueType type;
    private final int amount;
    private final String baseValue;
    private final int estimatedSize;

    ValueProfile(ValueType type, int amount) {
        this.type = type;
        this.amount = amount;
        this.baseValue = generateBaseValue(type, amount);
        // Append a small buffer that covers the suffix added per entry.
        this.estimatedSize = baseValue.length() + 24;
    }

    public String baseValue() {
        return baseValue;
    }

    public int estimatedSize() {
        return estimatedSize;
    }

    public String valueForIndex(int index) {
        return baseValue + "::entry-" + index;
    }

    private static String generateBaseValue(ValueType type, int amount) {
        switch (type) {
            case LINES:
                return buildLinePayload(amount);
            case BYTES:
                return buildBytePayload(amount);
            default:
                throw new IllegalStateException("Unsupported value type: " + type);
        }
    }

    private static String buildLinePayload(int lineCount) {
        StringBuilder builder = new StringBuilder(lineCount * (LINE_TEMPLATE.length() + 8));
        for (int i = 0; i < lineCount; i++) {
            builder.append(String.format(LINE_TEMPLATE, i))
                    .append(" :: lorem ipsum data")
                    .append('\n');
        }
        return builder.toString();
    }

    private static String buildBytePayload(int bytes) {
        char[] chars = new char[bytes];
        Arrays.fill(chars, 'x');
        return new String(chars);
    }

    private enum ValueType {
        LINES,
        BYTES
    }
}
