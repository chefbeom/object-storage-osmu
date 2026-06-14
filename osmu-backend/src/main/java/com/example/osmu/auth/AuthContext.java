package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Component;

@Component
public class AuthContext {

    private final UserRepository userRepository;

    public AuthContext(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    public AuthenticatedUser currentUser(HttpServletRequest request) {
        Object claims = request.getAttribute(JwtAuthInterceptor.CLAIMS_ATTRIBUTE);
        if (claims instanceof JwtClaims jwtClaims) {
            long userId = parseUserId(jwtClaims.subject());
            UserAccount user = userRepository.findById(userId)
                    .filter(account -> "ACTIVE".equals(account.status()))
                    .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid authenticated user."));
            return new AuthenticatedUser(user.id(), user.loginId(), user.role(), user.organizationId());
        }
        throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
    }

    private long parseUserId(String subject) {
        try {
            return Long.parseLong(subject);
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Invalid authenticated user.");
        }
    }
}
