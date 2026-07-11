package com.example.osmu.object;

import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;

public record ObjectLifecycleRulePageCursor(
        int priority,
        OffsetDateTime createdAt,
        String ruleId
) {
    private static final int HEADER_BYTES = Integer.BYTES * 4 + Long.BYTES;
    private static final int MAX_RULE_ID_BYTES = 256;

    public ObjectLifecycleRulePageCursor {
        if (priority < 1 || createdAt == null || ruleId == null || ruleId.isBlank()) {
            throw new IllegalArgumentException("Invalid lifecycle rule cursor.");
        }
        if (ruleId.getBytes(StandardCharsets.UTF_8).length > MAX_RULE_ID_BYTES) {
            throw new IllegalArgumentException("Invalid lifecycle rule cursor.");
        }
    }

    public static ObjectLifecycleRulePageCursor fromRule(ObjectLifecycleRule rule) {
        return new ObjectLifecycleRulePageCursor(rule.priority(), rule.createdAt(), rule.ruleId());
    }

    public String encode() {
        byte[] ruleIdBytes = ruleId.getBytes(StandardCharsets.UTF_8);
        ByteBuffer buffer = ByteBuffer.allocate(HEADER_BYTES + ruleIdBytes.length);
        buffer.putInt(priority);
        buffer.putLong(createdAt.toEpochSecond());
        buffer.putInt(createdAt.getNano());
        buffer.putInt(createdAt.getOffset().getTotalSeconds());
        buffer.putInt(ruleIdBytes.length);
        buffer.put(ruleIdBytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(buffer.array());
    }

    public static ObjectLifecycleRulePageCursor decode(String encoded) {
        try {
            if (encoded == null || encoded.isBlank() || encoded.length() > 512) {
                throw new IllegalArgumentException("Invalid lifecycle rule cursor.");
            }
            byte[] bytes = Base64.getUrlDecoder().decode(encoded);
            if (bytes.length < HEADER_BYTES) {
                throw new IllegalArgumentException("Invalid lifecycle rule cursor.");
            }
            ByteBuffer buffer = ByteBuffer.wrap(bytes);
            int priority = buffer.getInt();
            long epochSecond = buffer.getLong();
            int nano = buffer.getInt();
            int offsetSeconds = buffer.getInt();
            int ruleIdLength = buffer.getInt();
            if (nano < 0 || nano > 999_999_999
                    || ruleIdLength < 1
                    || ruleIdLength > MAX_RULE_ID_BYTES
                    || buffer.remaining() != ruleIdLength) {
                throw new IllegalArgumentException("Invalid lifecycle rule cursor.");
            }
            byte[] ruleIdBytes = new byte[ruleIdLength];
            buffer.get(ruleIdBytes);
            OffsetDateTime createdAt = OffsetDateTime.ofInstant(
                    Instant.ofEpochSecond(epochSecond, nano),
                    ZoneOffset.ofTotalSeconds(offsetSeconds)
            );
            return new ObjectLifecycleRulePageCursor(
                    priority,
                    createdAt,
                    new String(ruleIdBytes, StandardCharsets.UTF_8)
            );
        } catch (RuntimeException exception) {
            throw new IllegalArgumentException("Invalid lifecycle rule cursor.", exception);
        }
    }
}
