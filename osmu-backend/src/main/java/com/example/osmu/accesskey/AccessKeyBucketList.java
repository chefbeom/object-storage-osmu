package com.example.osmu.accesskey;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import java.util.List;

public record AccessKeyBucketList(
        AuthenticatedUser user,
        List<BucketRecord> buckets
) {
}
