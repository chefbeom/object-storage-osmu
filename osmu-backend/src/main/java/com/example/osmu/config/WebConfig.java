package com.example.osmu.config;

import com.example.osmu.auth.JwtAuthInterceptor;
import com.example.osmu.common.web.RequestIdFilter;
import java.util.Arrays;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.CorsRegistry;
import org.springframework.web.servlet.config.annotation.InterceptorRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

@Configuration
public class WebConfig implements WebMvcConfigurer {

    private final JwtAuthInterceptor jwtAuthInterceptor;
    private final String[] allowedOrigins;

    public WebConfig(
            JwtAuthInterceptor jwtAuthInterceptor,
            @Value("${osmu.api.cors.allowed-origins:http://localhost:5173,http://127.0.0.1:5173}") String allowedOrigins
    ) {
        this.jwtAuthInterceptor = jwtAuthInterceptor;
        this.allowedOrigins = parseAllowedOrigins(allowedOrigins);
    }

    @Override
    public void addCorsMappings(CorsRegistry registry) {
        registry.addMapping("/api/**")
                .allowedOrigins(allowedOrigins)
                .allowedMethods("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS")
                .allowedHeaders("*")
                .exposedHeaders(RequestIdFilter.REQUEST_ID_HEADER)
                .allowCredentials(false);
    }

    @Override
    public void addInterceptors(InterceptorRegistry registry) {
        registry.addInterceptor(jwtAuthInterceptor)
                .addPathPatterns("/api/**");
    }

    private String[] parseAllowedOrigins(String value) {
        String[] origins = Arrays.stream(value.split(","))
                .map(String::trim)
                .filter(origin -> !origin.isBlank())
                .toArray(String[]::new);
        return origins.length == 0
                ? new String[]{"http://localhost:5173", "http://127.0.0.1:5173"}
                : origins;
    }
}
