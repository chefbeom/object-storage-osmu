package com.example.osmu.user;

import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/users")
public class UserController {

    private final UserRepository userRepository;
    private final AuthContext authContext;

    public UserController(UserRepository userRepository, AuthContext authContext) {
        this.userRepository = userRepository;
        this.authContext = authContext;
    }

    @GetMapping("/me")
    public ApiResponse<UserProfile> me(HttpServletRequest request) {
        AuthenticatedUser user = authContext.currentUser(request);
        UserProfile profile = userRepository.findById(user.id())
                .map(UserAccount::toProfile)
                .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authenticated user not found."));
        return ApiResponse.of(profile);
    }
}
