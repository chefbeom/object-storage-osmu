package com.example.osmu.object;

import java.util.List;

public record StoredObjectPage(List<StoredObjectRecord> items, List<String> prefixes, String nextCursor) {

    public StoredObjectPage {
        items = items == null ? List.of() : List.copyOf(items);
        prefixes = prefixes == null ? List.of() : List.copyOf(prefixes);
    }

    public static StoredObjectPage recursive(List<StoredObjectRecord> items, String nextCursor) {
        return new StoredObjectPage(items, List.of(), nextCursor);
    }
}
