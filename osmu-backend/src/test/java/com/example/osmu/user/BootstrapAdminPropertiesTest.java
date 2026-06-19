package com.example.osmu.user;

import com.example.osmu.auth.PasswordService;
import java.util.Optional;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class BootstrapAdminPropertiesTest {

    private final PasswordService passwordService = new PasswordService();

    @Test
    void createsBootstrapAdminWhenEnabled() {
        BootstrapAdminProperties properties = new BootstrapAdminProperties(
                true,
                false,
                " root-admin ",
                "strong-password",
                " root@example.com ",
                " Root Admin "
        );

        Optional<UserAccount> result = properties.createAdmin(1L, passwordService);

        assertTrue(result.isPresent());
        UserAccount admin = result.get();
        assertEquals(1L, admin.id());
        assertEquals("root-admin", admin.loginId());
        assertEquals("root@example.com", admin.email());
        assertEquals("Root Admin", admin.name());
        assertEquals("ADMIN", admin.role());
        assertEquals("ACTIVE", admin.status());
        assertNull(admin.organizationId());
        assertTrue(passwordService.matches("strong-password", admin.passwordHash()));
    }

    @Test
    void disabledBootstrapSkipsAdminCreation() {
        BootstrapAdminProperties properties = new BootstrapAdminProperties(
                false,
                false,
                "",
                "",
                "",
                ""
        );

        assertFalse(properties.enabled());
        assertTrue(properties.createAdmin(1L, passwordService).isEmpty());
    }

    @Test
    void rejectsDefaultPasswordWhenDefaultCredentialsAreNotAllowed() {
        assertThrows(IllegalStateException.class, () -> new BootstrapAdminProperties(
                true,
                false,
                "admin",
                "password",
                "admin@example.com",
                "Admin"
        ));
    }

    @Test
    void rejectsBlankRequiredFieldsWhenEnabled() {
        assertThrows(IllegalStateException.class, () -> new BootstrapAdminProperties(
                true,
                true,
                "admin",
                " ",
                "admin@example.com",
                "Admin"
        ));
    }
}
