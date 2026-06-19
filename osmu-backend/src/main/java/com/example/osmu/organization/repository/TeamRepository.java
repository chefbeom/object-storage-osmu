package com.example.osmu.organization.repository;

import com.example.osmu.organization.TeamRecord;
import java.util.List;
import java.util.Optional;

public interface TeamRepository {

    List<TeamRecord> findAll();

    Optional<TeamRecord> findById(long id);

    boolean existsByOrganizationIdAndName(long organizationId, String name);

    long nextId();

    TeamRecord save(TeamRecord team);

    void deleteById(long id);

    List<Long> findMemberIds(long teamId);

    void replaceMembers(long teamId, List<Long> userIds);

    boolean hasMember(long teamId, long userId);

    boolean isHealthy();
}
