package com.example.osmu.object.repository;

import com.example.osmu.object.DeletedObjectCandidate;
import com.example.osmu.object.StoredObjectPage;
import com.example.osmu.object.StoredObjectRecord;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.TreeMap;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryObjectMetadataRepository implements ObjectMetadataRepository {

    private final ConcurrentMap<String, ConcurrentMap<String, StoredObjectRecord>> objectsByBucket =
            new ConcurrentHashMap<>();

    @Override
    public StoredObjectPage listObjects(
            String bucketName,
            String prefix,
            String delimiter,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    ) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        String normalizedDelimiter = delimiter == null ? "" : delimiter;
        String normalizedSearch = search == null ? "" : search.trim().toLowerCase();
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        String normalizedCursor = cursor == null ? "" : cursor;

        List<StoredObjectRecord> objects = bucketObjects(bucketName)
                .values()
                .stream()
                .filter(object -> !object.isDeleted())
                .filter(object -> object.key().startsWith(normalizedPrefix))
                .filter(object -> normalizedSearch.isBlank()
                        || object.key().toLowerCase().contains(normalizedSearch))
                .filter(object -> matchesTags(object, normalizedTagFilter))
                .sorted(Comparator.comparing(StoredObjectRecord::key))
                .toList();

        if (normalizedDelimiter.isBlank() || !normalizedSearch.isBlank() || !normalizedTagFilter.isEmpty()) {
            return toPage(objects.stream()
                    .filter(object -> normalizedCursor.isBlank() || object.key().compareTo(normalizedCursor) > 0)
                    .limit((long) limit + 1)
                    .toList(), limit);
        }

        Map<String, ListedObjectEntry> entries = new TreeMap<>();
        for (StoredObjectRecord object : objects) {
            addDelimitedEntry(entries, object, normalizedPrefix, normalizedDelimiter);
        }
        List<ListedObjectEntry> pageEntries = entries.values().stream()
                .filter(entry -> normalizedCursor.isBlank() || entry.key().compareTo(normalizedCursor) > 0)
                .limit((long) limit + 1)
                .toList();
        return toDelimitedPage(pageEntries, limit);
    }

    @Override
    public StoredObjectPage listDeletedObjects(
            String bucketName,
            String prefix,
            String search,
            Map<String, String> tagFilter,
            String cursor,
            int limit
    ) {
        String normalizedPrefix = prefix == null ? "" : prefix;
        String normalizedSearch = search == null ? "" : search.trim().toLowerCase();
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        String normalizedCursor = cursor == null ? "" : cursor;

        List<StoredObjectRecord> objects = bucketObjects(bucketName)
                .values()
                .stream()
                .filter(StoredObjectRecord::isDeleted)
                .filter(object -> object.key().startsWith(normalizedPrefix))
                .filter(object -> normalizedSearch.isBlank()
                        || object.key().toLowerCase().contains(normalizedSearch))
                .filter(object -> matchesTags(object, normalizedTagFilter))
                .sorted(Comparator.comparing(StoredObjectRecord::key))
                .filter(object -> normalizedCursor.isBlank() || object.key().compareTo(normalizedCursor) > 0)
                .limit((long) limit + 1)
                .toList();
        return toPage(objects, limit);
    }

    @Override
    public Optional<StoredObjectRecord> findByKey(String bucketName, String objectKey) {
        return Optional.ofNullable(bucketObjects(bucketName).get(objectKey));
    }

    @Override
    public List<DeletedObjectCandidate> findDeletedBefore(OffsetDateTime cutoff, int limit) {
        return findDeletedBefore(cutoff, limit, "", "", Map.of());
    }

    @Override
    public List<DeletedObjectCandidate> findDeletedBefore(
            OffsetDateTime cutoff,
            int limit,
            String prefix,
            Map<String, String> tagFilter
    ) {
        return findDeletedBefore(cutoff, limit, "", prefix, tagFilter);
    }

    @Override
    public List<DeletedObjectCandidate> findDeletedBefore(
            OffsetDateTime cutoff,
            int limit,
            String bucketName,
            String prefix,
            Map<String, String> tagFilter
    ) {
        String normalizedBucketName = bucketName == null ? "" : bucketName.trim();
        String normalizedPrefix = prefix == null ? "" : prefix;
        Map<String, String> normalizedTagFilter = tagFilter == null ? Map.of() : tagFilter;
        return objectsByBucket.entrySet()
                .stream()
                .filter(bucketEntry -> normalizedBucketName.isBlank() || bucketEntry.getKey().equals(normalizedBucketName))
                .flatMap(bucketEntry -> bucketEntry.getValue().values().stream()
                        .filter(StoredObjectRecord::isDeleted)
                        .filter(object -> !object.deletedAt().isAfter(cutoff))
                        .filter(object -> object.key().startsWith(normalizedPrefix))
                        .filter(object -> matchesTags(object, normalizedTagFilter))
                        .map(object -> new DeletedObjectCandidate(
                                bucketEntry.getKey(),
                                object.key(),
                                object.sizeBytes(),
                                object.deletedAt()
                        )))
                .sorted(Comparator.comparing(DeletedObjectCandidate::deletedAt)
                        .thenComparing(DeletedObjectCandidate::bucketName)
                        .thenComparing(DeletedObjectCandidate::key))
                .limit(limit)
                .toList();
    }

    @Override
    public StoredObjectRecord save(String bucketName, StoredObjectRecord object) {
        bucketObjects(bucketName).put(object.key(), object);
        return object;
    }

    @Override
    public void delete(String bucketName, String objectKey) {
        bucketObjects(bucketName).remove(objectKey);
    }

    @Override
    public void replaceBucketObjects(String bucketName, List<StoredObjectRecord> objects) {
        ConcurrentMap<String, StoredObjectRecord> replacement = new ConcurrentHashMap<>();
        for (StoredObjectRecord object : objects) {
            replacement.put(object.key(), object);
        }
        objectsByBucket.put(bucketName, replacement);
    }

    @Override
    public void deleteByBucketName(String bucketName) {
        objectsByBucket.remove(bucketName);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }

    private ConcurrentMap<String, StoredObjectRecord> bucketObjects(String bucketName) {
        return objectsByBucket.computeIfAbsent(bucketName, ignored -> new ConcurrentHashMap<>());
    }

    private boolean matchesTags(StoredObjectRecord object, Map<String, String> tagFilter) {
        if (tagFilter.isEmpty()) {
            return true;
        }
        return tagFilter.entrySet().stream()
                .allMatch(entry -> entry.getValue().equals(object.tags().get(entry.getKey())));
    }

    private StoredObjectPage toPage(List<StoredObjectRecord> objects, int limit) {
        if (objects.size() <= limit) {
            return StoredObjectPage.recursive(objects, null);
        }
        List<StoredObjectRecord> pageItems = List.copyOf(objects.subList(0, limit));
        return StoredObjectPage.recursive(pageItems, pageItems.get(pageItems.size() - 1).key());
    }

    private void addDelimitedEntry(
            Map<String, ListedObjectEntry> entries,
            StoredObjectRecord object,
            String prefix,
            String delimiter
    ) {
        String remainingKey = object.key().substring(prefix.length());
        int delimiterIndex = remainingKey.indexOf(delimiter);
        if (delimiterIndex >= 0) {
            String commonPrefix = prefix + remainingKey.substring(0, delimiterIndex + delimiter.length());
            entries.putIfAbsent(commonPrefix, new ListedObjectEntry(commonPrefix, null));
            return;
        }
        entries.putIfAbsent(object.key(), new ListedObjectEntry(object.key(), object));
    }

    private StoredObjectPage toDelimitedPage(List<ListedObjectEntry> entries, int limit) {
        boolean hasNext = entries.size() > limit;
        List<ListedObjectEntry> pageEntries = hasNext ? entries.subList(0, limit) : entries;
        List<StoredObjectRecord> objects = new ArrayList<>();
        List<String> prefixes = new ArrayList<>();
        for (ListedObjectEntry entry : pageEntries) {
            if (entry.isPrefix()) {
                prefixes.add(entry.key());
            } else {
                objects.add(entry.object());
            }
        }
        String nextCursor = hasNext ? pageEntries.get(pageEntries.size() - 1).key() : null;
        return new StoredObjectPage(objects, prefixes, nextCursor);
    }

    private record ListedObjectEntry(String key, StoredObjectRecord object) {
        private boolean isPrefix() {
            return object == null;
        }
    }
}
