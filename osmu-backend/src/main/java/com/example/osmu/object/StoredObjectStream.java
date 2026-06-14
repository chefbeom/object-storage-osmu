package com.example.osmu.object;

import java.io.InputStream;

public record StoredObjectStream(
        StoredObjectRecord metadata,
        InputStream content
) {
}
