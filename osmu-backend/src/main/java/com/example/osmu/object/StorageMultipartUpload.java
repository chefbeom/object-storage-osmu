package com.example.osmu.object;

import java.util.List;

public record StorageMultipartUpload(
        String storageUploadId,
        List<MultipartUploadPartUrl> parts
) {
}
