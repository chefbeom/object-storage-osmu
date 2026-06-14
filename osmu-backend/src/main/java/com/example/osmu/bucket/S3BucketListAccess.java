package com.example.osmu.bucket;

import com.example.osmu.auth.AuthenticatedUser;
import java.util.List;

public record S3BucketListAccess(
        AuthenticatedUser user,
        List<BucketRecord> buckets
) {
}
