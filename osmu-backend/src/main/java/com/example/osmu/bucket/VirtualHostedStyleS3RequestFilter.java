package com.example.osmu.bucket;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletRequestWrapper;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

@Component
public class VirtualHostedStyleS3RequestFilter extends OncePerRequestFilter {

    public static final String ORIGINAL_REQUEST_URI_ATTRIBUTE =
            VirtualHostedStyleS3RequestFilter.class.getName() + ".originalRequestUri";

    private static final String S3_PATH_PREFIX = "/api/s3";
    private static final Pattern BUCKET_NAME_PATTERN = Pattern.compile("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$");

    private final boolean enabled;
    private final List<String> domainSuffixes;

    public VirtualHostedStyleS3RequestFilter(
            @Value("${osmu.s3.virtual-hosted-style.enabled:true}") boolean enabled,
            @Value("${osmu.s3.virtual-hosted-style.domain-suffixes:localhost}") String domainSuffixes
    ) {
        this.enabled = enabled;
        this.domainSuffixes = Arrays.stream(domainSuffixes.split(","))
                .map(String::trim)
                .filter(value -> !value.isBlank())
                .map(VirtualHostedStyleS3RequestFilter::normalizeHostName)
                .toList();
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        if (!enabled || request.getAttribute(ORIGINAL_REQUEST_URI_ATTRIBUTE) != null) {
            filterChain.doFilter(request, response);
            return;
        }

        String requestUri = request.getRequestURI();
        if (requestUri == null) {
            filterChain.doFilter(request, response);
            return;
        }

        String bucketName = virtualHostedBucketName(request);
        if (bucketName == null) {
            filterChain.doFilter(request, response);
            return;
        }

        String targetPath = targetPath(requestUri, bucketName);
        if (targetPath == null) {
            filterChain.doFilter(request, response);
            return;
        }

        request.setAttribute(ORIGINAL_REQUEST_URI_ATTRIBUTE, requestUri);
        filterChain.doFilter(new VirtualHostedStyleRequest(request, targetPath), response);
    }

    private boolean isS3Path(String requestUri) {
        return S3_PATH_PREFIX.equals(requestUri) || requestUri.startsWith(S3_PATH_PREFIX + "/");
    }

    private String targetPath(String requestUri, String bucketName) {
        if (isS3Path(requestUri)) {
            String restPath = requestUri.length() == S3_PATH_PREFIX.length()
                    ? ""
                    : requestUri.substring(S3_PATH_PREFIX.length());
            return S3_PATH_PREFIX + "/" + bucketName + restPath;
        }
        if (requestUri.startsWith("/api/") || requestUri.startsWith("/actuator")) {
            return null;
        }
        String restPath = "/".equals(requestUri) ? "" : requestUri;
        return "/" + bucketName + restPath;
    }

    private String virtualHostedBucketName(HttpServletRequest request) {
        String host = request.getHeader(HttpHeaders.HOST);
        if (host == null || host.isBlank()) {
            host = request.getServerName();
        }
        String normalizedHost = normalizeHostName(host);
        for (String suffix : domainSuffixes) {
            if (normalizedHost.equals(suffix) || !normalizedHost.endsWith("." + suffix)) {
                continue;
            }
            String bucketName = normalizedHost.substring(0, normalizedHost.length() - suffix.length() - 1);
            if (BUCKET_NAME_PATTERN.matcher(bucketName).matches()) {
                return bucketName;
            }
        }
        return null;
    }

    private static String normalizeHostName(String value) {
        String host = value.trim().toLowerCase(Locale.ROOT);
        int portSeparator = host.lastIndexOf(':');
        if (portSeparator >= 0) {
            host = host.substring(0, portSeparator);
        }
        return host.startsWith(".") ? host.substring(1) : host;
    }

    private static final class VirtualHostedStyleRequest extends HttpServletRequestWrapper {
        private final String requestUri;

        private VirtualHostedStyleRequest(HttpServletRequest request, String requestUri) {
            super(request);
            this.requestUri = requestUri;
        }

        @Override
        public String getRequestURI() {
            return requestUri;
        }

        @Override
        public String getServletPath() {
            return requestUri;
        }

        @Override
        public String getPathInfo() {
            return null;
        }

        @Override
        public StringBuffer getRequestURL() {
            StringBuffer url = new StringBuffer();
            url.append(getScheme()).append("://").append(getServerName());
            int port = getServerPort();
            if (port > 0 && port != 80 && port != 443) {
                url.append(':').append(port);
            }
            url.append(requestUri);
            return url;
        }
    }
}
