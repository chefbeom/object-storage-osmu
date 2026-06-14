package com.example.osmu.organization.repository;

import com.example.osmu.organization.OrganizationRecord;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryOrganizationRepository implements OrganizationRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, OrganizationRecord> organizations = new ConcurrentHashMap<>();

    @Override
    public List<OrganizationRecord> findAll() {
        return organizations.values().stream()
                .sorted(Comparator.comparing(OrganizationRecord::id))
                .toList();
    }

    @Override
    public Optional<OrganizationRecord> findById(long id) {
        return Optional.ofNullable(organizations.get(id));
    }

    @Override
    public boolean existsByName(String name) {
        return organizations.values().stream()
                .anyMatch(organization -> organization.name().equalsIgnoreCase(name));
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public OrganizationRecord save(OrganizationRecord organization) {
        organizations.put(organization.id(), organization);
        return organization;
    }

    @Override
    public void deleteById(long id) {
        organizations.remove(id);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
