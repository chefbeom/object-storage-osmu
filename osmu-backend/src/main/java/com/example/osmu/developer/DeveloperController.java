package com.example.osmu.developer;

import com.example.osmu.common.api.ApiResponse;
import jakarta.servlet.http.HttpServletRequest;
import java.util.Arrays;
import java.util.List;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.servlet.support.ServletUriComponentsBuilder;

@RestController
@RequestMapping("/api/developer")
public class DeveloperController {

    private final String publicS3Endpoint;
    private final String region;
    private final boolean virtualHostedStyleEnabled;
    private final List<String> virtualHostedStyleDomainSuffixes;

    public DeveloperController(
            @Value("${osmu.s3.public-endpoint:}") String publicS3Endpoint,
            @Value("${osmu.s3.region:us-east-1}") String region,
            @Value("${osmu.s3.virtual-hosted-style.enabled:true}") boolean virtualHostedStyleEnabled,
            @Value("${osmu.s3.virtual-hosted-style.domain-suffixes:localhost}") String virtualHostedStyleDomainSuffixes
    ) {
        this.publicS3Endpoint = publicS3Endpoint == null ? "" : publicS3Endpoint.trim();
        this.region = region == null || region.isBlank() ? "us-east-1" : region.trim();
        this.virtualHostedStyleEnabled = virtualHostedStyleEnabled;
        this.virtualHostedStyleDomainSuffixes = parseCsv(virtualHostedStyleDomainSuffixes);
    }

    @GetMapping("/s3-client-config")
    public ApiResponse<S3ClientConfigResponse> s3ClientConfig(HttpServletRequest request) {
        return ApiResponse.of(new S3ClientConfigResponse(
                endpoint(request),
                region,
                "AWS4-HMAC-SHA256",
                "s3",
                true,
                virtualHostedStyleEnabled,
                virtualHostedStyleDomainSuffixes
        ));
    }

    private String endpoint(HttpServletRequest request) {
        if (!publicS3Endpoint.isBlank()) {
            return publicS3Endpoint;
        }
        return ServletUriComponentsBuilder.fromRequestUri(request)
                .replacePath("/api/s3")
                .replaceQuery(null)
                .build()
                .toUriString();
    }

    private List<String> parseCsv(String value) {
        if (value == null || value.isBlank()) {
            return List.of();
        }
        return Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(item -> !item.isBlank())
                .toList();
    }
}
