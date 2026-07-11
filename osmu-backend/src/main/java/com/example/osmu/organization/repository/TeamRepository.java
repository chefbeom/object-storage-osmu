package com.example.osmu.organization.repository;

import com.example.osmu.organization.TeamRecord;
import java.util.List;
import java.util.Map;
import java.util.Optional;

public interface TeamRepository {


    List<TeamRecord> findPage(Long organizationId, Long cursorId, int limit);

    List<Long> findIdsByMember(long userId);

    Optional<TeamRecord> findById(long id);

    boolean existsByOrganizationIdAndName(long organizationId, String name);

    boolean existsByOrganizationId(long organizationId);

    long nextId();

    TeamRecord save(TeamRecord team);

    void deleteById(long id);

    List<Long> findMemberIds(long teamId);

    Map<Long, List<Long>> findMemberIdsByTeamIds(List<Long> teamIds);

    void replaceMembers(long teamId, List<Long> userIds);

    boolean hasMember(long teamId, long userId);

    boolean isHealthy();
}
