package com.example.osmu.storageprofile;

public record StorageProfileStatusRequest(
        String status,
        String adminNote
) {
}
