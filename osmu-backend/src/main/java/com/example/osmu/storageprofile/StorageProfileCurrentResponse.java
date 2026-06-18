package com.example.osmu.storageprofile;

public record StorageProfileCurrentResponse(
        String bucketName,
        StorageProfileAssignmentResponse assignment,
        StorageProfileRequestResponse latestRequest
) {
}
