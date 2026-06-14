package com.example.osmu.common.error;

public record ErrorResponse(ErrorBody error) {

    public static ErrorResponse of(ApiErrorCode code, String message) {
        return of(code, message, null);
    }

    public static ErrorResponse of(ApiErrorCode code, String message, String requestId) {
        return new ErrorResponse(new ErrorBody(code.name(), message, requestId));
    }

    public record ErrorBody(String code, String message, String requestId) {
    }
}
