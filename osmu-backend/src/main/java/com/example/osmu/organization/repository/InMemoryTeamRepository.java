package com.example.osmu.organization.repository;

import com.example.osmu.organization.TeamRecord;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentMap;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Repository;

@Repository
@ConditionalOnProperty(prefix = "osmu.metadata", name = "mode", havingValue = "in-memory", matchIfMissing = true)
public class InMemoryTeamRepository implements TeamRepository {

    private final AtomicLong idSequence = new AtomicLong(1);
    private final ConcurrentMap<Long, TeamRecord> teams = new ConcurrentHashMap<>();
    private final ConcurrentMap<Long, LinkedHashSet<Long>> membersByTeamId = new ConcurrentHashMap<>();


    @Override
    public List<TeamRecord> findPage(Long organizationId, Long cursorId, int limit) {
        return teams.values().stream()
                .filter(team -> organizationId == null || team.organizationId() == organizationId)
                .filter(team -> cursorId == null || team.id() > cursorId)
                .sorted(Comparator.comparingLong(TeamRecord::id))
                .limit(limit)
                .toList();
    }

    @Override
    public List<Long> findIdsByMember(long userId) {
        return membersByTeamId.entrySet().stream()
                .filter(entry -> entry.getValue().contains(userId))
                .map(entry -> entry.getKey())
                .sorted()
                .toList();
    }

    @Override
    public Optional<TeamRecord> findById(long id) {
        return Optional.ofNullable(teams.get(id));
    }

    @Override
    public boolean existsByOrganizationIdAndName(long organizationId, String name) {
        return teams.values().stream()
                .anyMatch(team -> team.organizationId() == organizationId
                        && team.name().equalsIgnoreCase(name));
    }

    @Override
    public boolean existsByOrganizationId(long organizationId) {
        return teams.values().stream()
                .anyMatch(team -> team.organizationId() == organizationId);
    }

    @Override
    public long nextId() {
        return idSequence.getAndIncrement();
    }

    @Override
    public TeamRecord save(TeamRecord team) {
        teams.put(team.id(), team);
        return team;
    }

    @Override
    public void deleteById(long id) {
        teams.remove(id);
        membersByTeamId.remove(id);
    }

    @Override
    public List<Long> findMemberIds(long teamId) {
        return membersByTeamId.getOrDefault(teamId, new LinkedHashSet<>()).stream()
                .sorted()
                .toList();
    }

    @Override
    public java.util.Map<Long, List<Long>> findMemberIdsByTeamIds(List<Long> teamIds) {
        java.util.Set<Long> ids = teamIds == null
                ? java.util.Set.of()
                : new java.util.HashSet<>(teamIds);
        java.util.Map<Long, List<Long>> result = new java.util.LinkedHashMap<>();
        ids.stream().sorted().forEach(teamId -> {
            List<Long> memberIds = findMemberIds(teamId);
            if (!memberIds.isEmpty()) {
                result.put(teamId, memberIds);
            }
        });
        return result;
    }

    @Override
    public void replaceMembers(long teamId, List<Long> userIds) {
        membersByTeamId.put(teamId, new LinkedHashSet<>(userIds));
    }

    @Override
    public boolean hasMember(long teamId, long userId) {
        return membersByTeamId.getOrDefault(teamId, new LinkedHashSet<>()).contains(userId);
    }

    @Override
    public boolean isHealthy() {
        return true;
    }
}
