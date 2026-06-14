package com.example.osmu.organization.repository;

import com.example.osmu.organization.OrganizationRecord;
import java.util.List;
import java.util.Optional;

public interface OrganizationRepository {

    List<OrganizationRecord> findAll();

    Optional<OrganizationRecord> findById(long id);

    boolean existsByName(String name);

    long nextId();

    OrganizationRecord save(OrganizationRecord organization);

    void deleteById(long id);

    boolean isHealthy();
}
