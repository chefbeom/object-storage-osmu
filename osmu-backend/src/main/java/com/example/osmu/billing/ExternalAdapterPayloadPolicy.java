package com.example.osmu.billing;

import java.nio.charset.StandardCharsets;

final class ExternalAdapterPayloadPolicy {

    private static final int DEFAULT_MAX_PAYLOAD_BYTES = 65536;
    private static final int MIN_MAX_PAYLOAD_BYTES = 1024;
    private static final int MAX_MAX_PAYLOAD_BYTES = 262144;

    private ExternalAdapterPayloadPolicy() {
    }

    static int normalizeMaxPayloadBytes(int value) {
        if (value <= 0) {
            return DEFAULT_MAX_PAYLOAD_BYTES;
        }
        return Math.max(MIN_MAX_PAYLOAD_BYTES, Math.min(value, MAX_MAX_PAYLOAD_BYTES));
    }

    static boolean exceedsMaxPayloadBytes(String value, int maxPayloadBytes) {
        if (value == null) {
            return false;
        }
        return value.getBytes(StandardCharsets.UTF_8).length > maxPayloadBytes;
    }
}
