package com.example.osmu.quota;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Set;

public record QuotaPolicyPageCursor(String targetType, long targetId) {
    private static final Set<String> TARGET_TYPES = Set.of("USER", "ORGANIZATION", "BUCKET");
    private static final int HEADER_BYTES = Integer.BYTES + Long.BYTES;
    private static final int MAX_TARGET_TYPE_BYTES = 32;

    public QuotaPolicyPageCursor {
        if (!TARGET_TYPES.contains(targetType) || targetId <= 0) {
            throw new IllegalArgumentException("Invalid quota policy cursor.");
        }
    }

    public static QuotaPolicyPageCursor fromPolicy(QuotaPolicy policy) {
        return new QuotaPolicyPageCursor(policy.targetType(), policy.targetId());
    }

    public String encode() {
        byte[] targetTypeBytes = targetType.getBytes(StandardCharsets.UTF_8);
        ByteBuffer buffer = ByteBuffer.allocate(HEADER_BYTES + targetTypeBytes.length);
        buffer.putInt(targetTypeBytes.length);
        buffer.putLong(targetId);
        buffer.put(targetTypeBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(buffer.array());
    }

    public static QuotaPolicyPageCursor decode(String encoded) {
        try {
            if (encoded == null || encoded.isBlank() || encoded.length() > 128) {
                throw new IllegalArgumentException("Invalid quota policy cursor.");
            }
            byte[] bytes = Base64.getUrlDecoder().decode(encoded);
            if (bytes.length < HEADER_BYTES) {
                throw new IllegalArgumentException("Invalid quota policy cursor.");
            }
            ByteBuffer buffer = ByteBuffer.wrap(bytes);
            int targetTypeLength = buffer.getInt();
            long targetId = buffer.getLong();
            if (targetTypeLength < 1
                    || targetTypeLength > MAX_TARGET_TYPE_BYTES
                    || buffer.remaining() != targetTypeLength) {
                throw new IllegalArgumentException("Invalid quota policy cursor.");
            }
            byte[] targetTypeBytes = new byte[targetTypeLength];
            buffer.get(targetTypeBytes);
            return new QuotaPolicyPageCursor(new String(targetTypeBytes, StandardCharsets.UTF_8), targetId);
        } catch (RuntimeException exception) {
            throw new IllegalArgumentException("Invalid quota policy cursor.", exception);
        }
    }
}