package com.example.osmu.object;

import java.util.List;

public record MultipartUploadListResponse(
        String bucketName,
        String prefix,
        String keyMarker,
        String uploadIdMarker,
        int maxUploads,
        boolean truncated,
        String nextKeyMarker,
        String nextUploadIdMarker,
        List<MultipartUploadListItem> uploads
) {
}
