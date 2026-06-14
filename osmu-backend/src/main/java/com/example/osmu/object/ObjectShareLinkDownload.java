package com.example.osmu.object;

public record ObjectShareLinkDownload(
        ObjectShareLink link,
        StoredObjectStream object
) {
}
