package com.example.osmu.object;

public final class ObjectVersionStorageKeys {

    public static final String PREFIX = ".osmu/versions/";
    public static final String UPLOAD_STAGING_PREFIX = ".osmu/uploads/";

    private ObjectVersionStorageKeys() {
    }

    public static boolean isVersionStorageKey(String key) {
        return key != null && key.startsWith(PREFIX);
    }

    public static boolean isUploadStagingStorageKey(String key) {
        return key != null && key.startsWith(UPLOAD_STAGING_PREFIX);
    }

    public static boolean isInternalStorageKey(String key) {
        return isVersionStorageKey(key) || isUploadStagingStorageKey(key);
    }
}
