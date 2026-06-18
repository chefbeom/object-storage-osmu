package com.example.osmu.accesskey;

import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public record BulkDisableAccessKeysRequest(
        @NotEmpty @Size(max = 100) List<@NotNull Long> keyIds
) {
}
