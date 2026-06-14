package com.example.osmu.common.api;

import java.util.List;

public record ListResponse<T>(List<T> items, String nextCursor) {

    public static <T> ListResponse<T> of(List<T> items) {
        return new ListResponse<>(items, null);
    }

    public static <T> ListResponse<T> of(List<T> items, String nextCursor) {
        return new ListResponse<>(items, nextCursor);
    }
}
