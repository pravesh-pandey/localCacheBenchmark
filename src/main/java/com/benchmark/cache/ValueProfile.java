package com.benchmark.cache;

import java.util.Arrays;
import java.util.Locale;

/**
 * Flexible payload profile that supports arbitrary line or byte sizes.
 * The profile generates deterministic sample values so benchmark iterations
 * are comparable regardless of payload size.
 */
public final class ValueProfile {

    private static final String LINE_TEMPLATE = "benchmark-value-line-%04d";

    private final ValueType type;
    private final int amount;
    private final String baseValue;
    private final int estimatedSize;

    private ValueProfile(ValueType type, int amount) {
        if (amount <= 0) {
            throw new IllegalArgumentException("Amount must be positive (was " + amount + ")");
        }
        this.type = type;
        this.amount = amount;
        this.baseValue = generateBaseValue(type, amount);
        // Append a small buffer that covers the suffix added per entry.
        this.estimatedSize = baseValue.length() + 24;
    }

    public static ValueProfile parse(String spec) {
        if (spec == null) {
            throw new IllegalArgumentException("Value profile spec must not be null");
        }
        String normalized = spec.trim();
        if (normalized.isEmpty()) {
            throw new IllegalArgumentException("Value profile spec must not be empty");
        }
        normalized = normalized.toUpperCase(Locale.ROOT);
        if (normalized.startsWith("LINES_")) {
            int lines = parsePositiveInt(normalized.substring("LINES_".length()), "line count");
            return forLines(lines);
        }
        if (normalized.startsWith("BYTES_")) {
            int bytes = parsePositiveInt(normalized.substring("BYTES_".length()), "byte count");
            return forBytes(bytes);
        }
        throw new IllegalArgumentException("Unsupported value profile '" + spec + "'. Expected formats: LINES_<n> or BYTES_<n>.");
    }

    public static ValueProfile forLines(int lineCount) {
        return new ValueProfile(ValueType.LINES, lineCount);
    }

    public static ValueProfile forBytes(int byteCount) {
        return new ValueProfile(ValueType.BYTES, byteCount);
    }

    private static int parsePositiveInt(String token, String description) {
        try {
            int value = Integer.parseInt(token);
            if (value <= 0) {
                throw new IllegalArgumentException("The " + description + " must be positive (was " + value + ")");
            }
            return value;
        } catch (NumberFormatException ex) {
            throw new IllegalArgumentException("Unable to parse " + description + " from '" + token + "'", ex);
        }
    }

    public String baseValue() {
        return baseValue;
    }

    public int estimatedSize() {
        return estimatedSize;
    }

    public ValueGenerator createGenerator(int maxUniqueValues) {
        return new ValueGenerator(baseValue, Math.max(1, Math.min(maxUniqueValues, 256)));
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

    public static final class ValueGenerator {
        private final String[] samples;

        private ValueGenerator(String baseValue, int count) {
            this.samples = new String[count];
            for (int i = 0; i < count; i++) {
                samples[i] = baseValue + "::sample-" + i;
            }
        }

        public String valueAt(int index) {
            return samples[index % samples.length];
        }
    }

    private enum ValueType {
        LINES,
        BYTES
    }
}
