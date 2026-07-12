package com.example.osmu.user;

import com.example.osmu.auth.PasswordService;
import java.util.Optional;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class BootstrapAdminProperties {

    private static final String DEFAULT_PASSWORD = "password";

    private final boolean enabled;
    private final boolean allowDefaultCredentials;
    private final String loginId;
    private final String password;
    private final String email;
    private final String name;

    public BootstrapAdminProperties(
            @Value("${osmu.bootstrap.admin.enabled:false}") boolean enabled,
            @Value("${osmu.bootstrap.admin.allow-default-credentials:false}") boolean allowDefaultCredentials,
            @Value("${osmu.bootstrap.admin.login-id:}") String loginId,
            @Value("${osmu.bootstrap.admin.password:}") String password,
            @Value("${osmu.bootstrap.admin.email:}") String email,
            @Value("${osmu.bootstrap.admin.name:}") String name
    ) {
        this.enabled = enabled;
        this.allowDefaultCredentials = allowDefaultCredentials;
        this.loginId = clean(loginId);
        this.password = clean(password);
        this.email = clean(email);
        this.name = clean(name);
        validate();
    }

    public boolean enabled() {
        return enabled;
    }

    public Optional<UserAccount> createAdmin(long id, PasswordService passwordService) {
        if (!enabled) {
            return Optional.empty();
        }
        return Optional.of(new UserAccount(
                id,
                loginId,
                email,
                name,
                passwordService.hash(password),
                "ADMIN",
                "ACTIVE",
                null
        ));
    }

    private void validate() {
        if (!enabled) {
            return;
        }
        requireNonBlank(loginId, "osmu.bootstrap.admin.login-id");
        requireNonBlank(password, "osmu.bootstrap.admin.password");
        requireNonBlank(email, "osmu.bootstrap.admin.email");
        requireNonBlank(name, "osmu.bootstrap.admin.name");
        if (!allowDefaultCredentials && DEFAULT_PASSWORD.equals(password)) {
            throw new IllegalStateException(
                    "Default bootstrap admin password is not allowed when "
                            + "osmu.bootstrap.admin.allow-default-credentials=false."
            );
        }
    }

    private static String clean(String value) {
        return value == null ? "" : value.trim();
    }

    private static void requireNonBlank(String value, String propertyName) {
        if (value.isBlank()) {
            throw new IllegalStateException(propertyName + " must not be blank when bootstrap admin is enabled.");
        }
    }
}
