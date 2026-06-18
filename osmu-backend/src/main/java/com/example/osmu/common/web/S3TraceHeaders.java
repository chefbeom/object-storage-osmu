package com.example.osmu.common.web;

import jakarta.servlet.http.HttpServletRequest;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;

public final class S3TraceHeaders {

    public static final String REQUEST_ID_HEADER = "x-amz-request-id";
    public static final String HOST_ID_HEADER = "x-amz-id-2";

    private static final String S3_PATH_PREFIX = "/api/s3";

    private S3TraceHeaders() {
    }

    public static boolean isS3Request(HttpServletRequest request) {
        if (request == null || request.getRequestURI() == null) {
            return false;
        }
        String uri = request.getRequestURI();
        if (S3_PATH_PREFIX.equals(uri) || uri.startsWith(S3_PATH_PREFIX + "/")) {
            return true;
        }
        if (uri.startsWith("/api/") || uri.startsWith("/actuator")) {
            return false;
        }
        String authorization = request.getHeader("Authorization");
        return (authorization != null && authorization.startsWith("AWS4-HMAC-SHA256 "))
                || "AWS4-HMAC-SHA256".equals(request.getParameter("X-Amz-Algorithm"))
                || hasText(request.getHeader("X-OSMU-Access-Key"))
                || hasText(request.getHeader("X-OSMU-Secret-Key"));
    }

    public static String resource(HttpServletRequest request) {
        if (request == null || request.getRequestURI() == null) {
            return "";
        }
        String query = request.getQueryString();
        return query == null || query.isBlank()
                ? request.getRequestURI()
                : request.getRequestURI() + "?" + query;
    }

    public static String hostId(String requestId, String resource) {
        if (!hasText(requestId)) {
            return "";
        }
        try {
            String seed = requestId + ":" + (resource == null ? "" : resource);
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(seed.getBytes(StandardCharsets.UTF_8));
            return Base64.getEncoder().encodeToString(digest);
        } catch (NoSuchAlgorithmException exception) {
            return requestId;
        }
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
