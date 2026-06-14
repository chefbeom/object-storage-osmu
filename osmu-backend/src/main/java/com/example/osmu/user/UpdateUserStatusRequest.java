package com.example.osmu.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;

public record UpdateUserStatusRequest(
        @NotBlank @Pattern(regexp = "ACTIVE|INACTIVE|LOCKED") String status
) {
}
