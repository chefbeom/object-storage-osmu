package com.example.osmu.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.repository.InMemoryUserRepository;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class OidcClaimPreviewServiceTest {

    @Test
    void previewRequiresAdminApprovalWhenNoLocalUserMatchesAllowedEmail() {
        OidcClaimPreviewResponse preview = service("example.com").preview(Map.of(
                "sub", "oidc-user-1",
                "email", "new.user@example.com",
                "name", "New User",
                "groups", List.of("osmu-org-admins"),
                "department", "platform",
                "teams", List.of("media")
        ));

        assertThat(preview.status()).isEqualTo("REQUIRES_ADMIN_APPROVAL");
        assertThat(preview.primaryRole()).isEqualTo("ORG_ADMIN");
        assertThat(preview.existingUser()).isNull();
        assertThat(preview.jitProvisioningRequired()).isTrue();
        assertThat(preview.adminApprovalRequired()).isTrue();
        assertThat(preview.warnings()).anyMatch(message -> message.contains("admin approval"));
    }

    @Test
    void previewRejectsDisallowedDomainBeforeJitProvisioning() {
        OidcClaimPreviewResponse preview = service("corp.example.com").preview(Map.of(
                "sub", "oidc-user-1",
                "email", "new.user@example.com",
                "groups", List.of("osmu-admins")
        ));

        assertThat(preview.status()).isEqualTo("REJECTED_DOMAIN");
        assertThat(preview.allowedDomainMatched()).isFalse();
        assertThat(preview.jitProvisioningRequired()).isFalse();
    }

    private OidcClaimPreviewService service(String allowedDomains) {
        return new OidcClaimPreviewService(
                new InMemoryUserRepository(
                        new PasswordService(),
                        new BootstrapAdminProperties(true, true, "admin", "password", "admin@example.com", "Admin")
                ),
                "sub",
                "email",
                "name",
                "groups",
                "department",
                "teams",
                allowedDomains
        );
    }
}
