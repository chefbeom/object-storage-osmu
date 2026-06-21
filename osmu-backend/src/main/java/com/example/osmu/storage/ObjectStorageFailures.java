package com.example.osmu.storage;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.util.function.Supplier;

public final class ObjectStorageFailures {

    private ObjectStorageFailures() {
    }

    public static <T> T run(String operation, Supplier<T> supplier) {
        try {
            return supplier.get();
        } catch (ApiException exception) {
            throw exception;
        } catch (RuntimeException exception) {
            throw storageError(operation, exception);
        }
    }

    public static void run(String operation, Runnable runnable) {
        run(operation, () -> {
            runnable.run();
            return null;
        });
    }

    private static ApiException storageError(String operation, RuntimeException exception) {
        String message = exception.getMessage();
        String suffix = message == null || message.isBlank() ? "." : ": " + message;
        return new ApiException(ApiErrorCode.STORAGE_ERROR, "Object storage " + operation + " failed" + suffix);
    }
}
