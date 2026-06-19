package com.example.osmu.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.example.osmu.auth.repository.InMemoryRefreshTokenRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.BootstrapAdminProperties;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.InMemoryUserRepository;
import com.example.osmu.user.repository.UserRepository;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.Test;

class LdapLoginServiceTest {

    @Test
    void ldapLoginBindsDirectoryUserAndIssuesTokensForExistingActiveLocalEmail() {
        CapturingLdapClient ldapClient = new CapturingLdapClient(new LdapUserRecord(
                "uid=admin,ou=people,dc=example,dc=com",
                "admin@example.com",
                "Admin"
        ));
        LdapLoginService service = service(ldapClient, userRepository(), true, "example.com");

        LoginResponse response = service.login(new LdapLoginRequest("admin", "ldap-password"));

        assertThat(response.user().loginId()).isEqualTo("admin");
        assertThat(response.user().role()).isEqualTo("ADMIN");
        assertThat(response.accessToken()).isNotBlank();
        assertThat(response.refreshToken()).isNotBlank();
        assertThat(ldapClient.searchRequest.get().loginId()).isEqualTo("admin");
        assertThat(ldapClient.bindRequest.get().userDn()).isEqualTo("uid=admin,ou=people,dc=example,dc=com");
        assertThat(ldapClient.bindRequest.get().password()).isEqualTo("ldap-password");
    }

    @Test
    void ldapLoginIsDisabledByDefault() {
        LdapLoginService service = service(
                new CapturingLdapClient(new LdapUserRecord("uid=admin", "admin@example.com", "Admin")),
                userRepository(),
                false,
                "example.com"
        );

        assertThatThrownBy(() -> service.login(new LdapLoginRequest("admin", "ldap-password")))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
    }

    @Test
    void ldapLoginRejectsDisallowedEmailDomain() {
        LdapLoginService service = service(
                new CapturingLdapClient(new LdapUserRecord("uid=admin", "admin@example.com", "Admin")),
                userRepository(),
                true,
                "corp.example.com"
        );

        assertThatThrownBy(() -> service.login(new LdapLoginRequest("admin", "ldap-password")))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.AUTHENTICATION_REQUIRED));
    }

    @Test
    void ldapLoginRequiresExistingActiveLocalUser() {
        LdapLoginService service = service(
                new CapturingLdapClient(new LdapUserRecord("uid=new", "new.user@example.com", "New User")),
                userRepository(),
                true,
                "example.com"
        );

        assertThatThrownBy(() -> service.login(new LdapLoginRequest("new", "ldap-password")))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.AUTHENTICATION_REQUIRED));
    }

    @Test
    void ldapLoginRejectsInactiveLocalEmail() {
        UserRepository userRepository = userRepository();
        userRepository.save(new UserAccount(
                userRepository.nextId(),
                "inactive-user",
                "inactive.user@example.com",
                "Inactive User",
                new PasswordService().hash("inactive-password"),
                "USER",
                "INACTIVE",
                null
        ));
        LdapLoginService service = service(
                new CapturingLdapClient(new LdapUserRecord("uid=inactive", "inactive.user@example.com", "Inactive User")),
                userRepository,
                true,
                "example.com"
        );

        assertThatThrownBy(() -> service.login(new LdapLoginRequest("inactive", "ldap-password")))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.AUTHENTICATION_REQUIRED));
    }

    private LdapLoginService service(
            LdapClient ldapClient,
            UserRepository userRepository,
            boolean enabled,
            String allowedDomains
    ) {
        JwtTokenService jwtTokenService = new JwtTokenService(
                "0123456789abcdef0123456789abcdef",
                "osmu",
                3600,
                604800
        );
        RefreshTokenService refreshTokenService = new RefreshTokenService(
                new InMemoryRefreshTokenRepository(),
                jwtTokenService
        );
        return new LdapLoginService(
                ldapClient,
                jwtTokenService,
                refreshTokenService,
                userRepository,
                enabled,
                "ldap://directory.example.com:389",
                "cn=osmu,dc=example,dc=com",
                "service-password",
                "ou=people,dc=example,dc=com",
                "(&(objectClass=person)(mail={0}))",
                "mail",
                "displayName",
                3000,
                3000,
                allowedDomains
        );
    }

    private UserRepository userRepository() {
        return new InMemoryUserRepository(
                new PasswordService(),
                new BootstrapAdminProperties(true, true, "admin", "password", "admin@example.com", "Admin")
        );
    }

    private static final class CapturingLdapClient implements LdapClient {

        private final LdapUserRecord user;
        private final AtomicReference<LdapSearchRequest> searchRequest = new AtomicReference<>();
        private final AtomicReference<LdapBindRequest> bindRequest = new AtomicReference<>();

        private CapturingLdapClient(LdapUserRecord user) {
            this.user = user;
        }

        @Override
        public LdapUserRecord searchUser(LdapSearchRequest request) {
            searchRequest.set(request);
            return user;
        }

        @Override
        public void bind(LdapBindRequest request) {
            bindRequest.set(request);
        }
    }
}
