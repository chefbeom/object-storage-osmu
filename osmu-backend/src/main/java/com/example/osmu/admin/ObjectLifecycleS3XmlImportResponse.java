package com.example.osmu.admin;

import com.example.osmu.object.ObjectLifecycleRule;
import java.util.List;

public record ObjectLifecycleS3XmlImportResponse(
        int importedCount,
        List<ObjectLifecycleRule> rules
) {
}
