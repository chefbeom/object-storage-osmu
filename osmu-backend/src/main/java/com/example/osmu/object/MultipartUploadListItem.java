package com.example.osmu.object;

import java.time.OffsetDateTime;

public record MultipartUploadListItem(
        String key,
        String uploadId,
        OffsetDateTime initiatedAt
) {
}
