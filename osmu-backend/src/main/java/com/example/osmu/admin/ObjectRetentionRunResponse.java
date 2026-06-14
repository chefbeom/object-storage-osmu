package com.example.osmu.admin;

public record ObjectRetentionRunResponse(
        int purgedCount,
        int purgedVersionCount,
        ObjectRetentionStatusResponse status
) {
}
