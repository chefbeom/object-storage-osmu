package com.example.osmu.object;

public record StoredObjectData(
        StoredObjectRecord metadata,
        byte[] content
) {
}
