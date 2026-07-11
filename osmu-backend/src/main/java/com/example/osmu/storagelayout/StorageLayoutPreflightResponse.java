package com.example.osmu.storagelayout;

import java.util.List;

public record StorageLayoutPreflightResponse(
        String result,
        boolean simulationOnly,
        List<StorageLayoutPreflightCheck> checks
) {
}
