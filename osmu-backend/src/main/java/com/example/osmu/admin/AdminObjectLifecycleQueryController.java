package com.example.osmu.admin;

import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.object.ObjectLifecycleRule;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/object-lifecycle")
public class AdminObjectLifecycleQueryController {

    private final ObjectLifecycleRuleQueryService queryService;

    public AdminObjectLifecycleQueryController(ObjectLifecycleRuleQueryService queryService) {
        this.queryService = queryService;
    }

    @GetMapping("/rules")
    public ListResponse<ObjectLifecycleRule> rules(
            @RequestParam(value = "status", required = false) String status,
            @RequestParam(value = "targetType", required = false) String targetType,
            @RequestParam(value = "cursor", required = false) String cursor,
            @RequestParam(value = "limit", required = false) Integer limit
    ) {
        return queryService.list(status, targetType, cursor, limit);
    }

    @GetMapping("/conflicts")
    public ApiResponse<ObjectLifecycleRuleConflictReportResponse> conflicts() {
        return ApiResponse.of(queryService.conflicts());
    }

    @GetMapping("/s3-xml")
    public ApiResponse<ObjectLifecycleS3XmlResponse> exportS3Xml() {
        return ApiResponse.of(queryService.exportS3Xml());
    }
}
