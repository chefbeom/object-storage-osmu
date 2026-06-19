package com.example.osmu.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.OrganizationRecord;
import com.example.osmu.organization.repository.InMemoryOrganizationRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.InMemoryUserRepository;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class OidcJitProvisioningServiceTest {

    @Test
    void provisionsAllowedOidcClaimsAsLocalUserAfterAdminRoleApproval() {
        Fixture fixture = fixture("example.com");

        OidcJitProvisionResponse response = fixture.service().provision(new OidcJitProvisionRequest(
                claims("oidc-user-1", "new.user@example.com", "New User", List.of("external-users")),
                "USER",
                null,
                false,
                "pilot import"
        ));

        assertThat(response.status()).isEqualTo("PROVISIONED");
        assertThat(response.user().loginId()).isEqualTo("new.user");
        assertThat(response.user().email()).isEqualTo("new.user@example.com");
        assertThat(response.user().role()).isEqualTo("USER");
        assertThat(response.preview().status()).isEqualTo("REQUIRES_ADMIN_APPROVAL");
        assertThat(fixture.userRepository().findByEmail("new.user@example.com"))
                .map(UserAccount::status)
                .contains("ACTIVE");
    }

    @Test
    void privilegedRoleProvisioningRequiresExplicitApprovalFlag() {
        Fixture fixture = fixture("example.com");

        assertThatThrownBy(() -> fixture.service().provision(new OidcJitProvisionRequest(
                claims("oidc-admin-1", "new.admin@example.com", "New Admin", List.of("osmu-admins")),
                "ADMIN",
                null,
                false,
                "admin import"
        )))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("Privileged OIDC role provisioning requires explicit approval");
    }

    @Test
    void orgAdminProvisioningRequiresExistingOrganization() {
        Fixture fixture = fixture("example.com");
        OrganizationRepository organizations = fixture.organizationRepository();
        organizations.save(new OrganizationRecord(organizations.nextId(), "Platform", "Platform team", 1024L, OffsetDateTime.now()));

        OidcJitProvisionResponse response = fixture.service().provision(new OidcJitProvisionRequest(
                claims("oidc-org-admin-1", "org.admin@example.com", "Org Admin", List.of("osmu-org-admins")),
                "ORG_ADMIN",
                1L,
                true,
                "org admin import"
        ));

        assertThat(response.status()).isEqualTo("PROVISIONED");
        assertThat(response.user().role()).isEqualTo("ORG_ADMIN");
        assertThat(response.user().organizationId()).isEqualTo(1L);
    }

    @Test
    void rejectsDisallowedDomainBeforeCreatingUser() {
        Fixture fixture = fixture("corp.example.com");

        assertThatThrownBy(() -> fixture.service().provision(new OidcJitProvisionRequest(
                claims("oidc-user-1", "new.user@example.com", "New User", List.of("external-users")),
                "USER",
                null,
                false,
                "pilot import"
        )))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("OIDC email domain is not allowed");
        assertThat(fixture.userRepository().findByEmail("new.user@example.com")).isEmpty();
    }

    @Test
    void rejectsProvisioningWhenEmailBelongsToInactiveLocalUser() {
        Fixture fixture = fixture("example.com");
        fixture.userRepository().save(new UserAccount(
                fixture.userRepository().nextId(),
                "inactive-user",
                "inactive.user@example.com",
                "Inactive User",
                new PasswordService().hash("inactive-password"),
                "USER",
                "INACTIVE",
                null
        ));

        assertThatThrownBy(() -> fixture.service().provision(new OidcJitProvisionRequest(
                claims("oidc-inactive-1", "inactive.user@example.com", "Inactive User", List.of("external-users")),
                "USER",
                null,
                false,
                "reactivation attempt"
        )))
                .isInstanceOf(ApiException.class)
                .hasMessageContaining("OIDC email is already assigned to a non-active local user");
    }

    private Map<String, Object> claims(String subject, String email, String name, List<String> groups) {
        return Map.of(
                "sub", subject,
                "email", email,
                "name", name,
                "groups", groups
        );
    }

    private Fixture fixture(String allowedDomains) {
        PasswordService passwordService = new PasswordService();
        UserRepository userRepository = new InMemoryUserRepository(
                passwordService,
                new BootstrapAdminProperties(true, true, "admin", "password", "admin@example.com", "Admin")
        );
        OrganizationRepository organizationRepository = new InMemoryOrganizationRepository();
        OidcClaimPreviewService claimPreviewService = new OidcClaimPreviewService(
                userRepository,
                "sub",
                "email",
                "name",
                "groups",
                "department",
                "teams",
                allowedDomains
        );
        return new Fixture(
                userRepository,
                organizationRepository,
                new OidcJitProvisioningService(claimPreviewService, userRepository, organizationRepository, passwordService)
        );
    }

    private record Fixture(
            UserRepository userRepository,
            OrganizationRepository organizationRepository,
            OidcJitProvisioningService service
    ) {
    }
}
