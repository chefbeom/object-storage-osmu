package com.example.osmu.organization;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.accesskey.AccessKeyService;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/admin/teams")
public class AdminTeamController {

    private static final int DEFAULT_LIST_LIMIT = 50;
    private static final int MAX_LIST_LIMIT = 200;

    private final TeamRepository teamRepository;
    private final OrganizationRepository organizationRepository;
    private final UserRepository userRepository;
    private final BucketPermissionRepository bucketPermissionRepository;
    private final AccessKeyService accessKeyService;
    private final AuditLogService auditLogService;
    private final AuthContext authContext;

    public AdminTeamController(
            TeamRepository teamRepository,
            OrganizationRepository organizationRepository,
            UserRepository userRepository,
            BucketPermissionRepository bucketPermissionRepository,
            AccessKeyService accessKeyService,
            AuditLogService auditLogService,
            AuthContext authContext
    ) {
        this.teamRepository = teamRepository;
        this.organizationRepository = organizationRepository;
        this.userRepository = userRepository;
        this.bucketPermissionRepository = bucketPermissionRepository;
        this.accessKeyService = accessKeyService;
        this.auditLogService = auditLogService;
        this.authContext = authContext;
    }

    @GetMapping
    public ListResponse<TeamResponse> list(
            @RequestParam(value = "organizationId", required = false) Long organizationId,
            @RequestParam(value = "limit", required = false) Integer limit,
            @RequestParam(value = "cursor", required = false) String cursor,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        Long scopedOrganizationId = listOrganizationId(actor, organizationId);
        if (scopedOrganizationId != null
                && actor.isOrgAdmin()
                && organizationId != null
                && organizationId.longValue() != scopedOrganizationId) {
            return ListResponse.of(List.of());
        }
        int pageSize = normalizeLimit(limit);
        List<TeamRecord> matchedTeams = teamRepository.findPage(
                scopedOrganizationId,
                cursorId(cursor),
                pageSize + 1
        );
        boolean hasNextPage = matchedTeams.size() > pageSize;
        List<TeamRecord> teamRecords = hasNextPage
                ? matchedTeams.subList(0, pageSize)
                : matchedTeams;
        Map<Long, List<Long>> memberIdsByTeam = teamRecords.isEmpty()
                ? Map.of()
                : teamRepository.findMemberIdsByTeamIds(
                        teamRecords.stream().map(TeamRecord::id).toList()
                );
        List<TeamResponse> teams = teamRecords.stream()
                .map(team -> TeamResponse.of(team, memberIdsByTeam.getOrDefault(team.id(), List.of())))
                .toList();
        String nextCursor = hasNextPage
                ? String.valueOf(teamRecords.get(teamRecords.size() - 1).id())
                : null;
        return ListResponse.of(teams, nextCursor);
    }

    @PostMapping
    public ApiResponse<TeamResponse> create(
            @Valid @RequestBody CreateTeamRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        long organizationId = resolveOrganizationId(actor, request.organizationId());
        validateOrganization(organizationId);
        String name = normalizedName(request.name());
        if (teamRepository.existsByOrganizationIdAndName(organizationId, name)) {
            throw new ApiException(ApiErrorCode.CONFLICT, "Team already exists.");
        }
        List<Long> memberIds = validateMemberIds(actor, organizationId, request.memberIds());

        OffsetDateTime now = OffsetDateTime.now();
        TeamRecord team = teamRepository.save(new TeamRecord(
                teamRepository.nextId(),
                organizationId,
                name,
                request.description() == null ? "" : request.description().trim(),
                now,
                now
        ));
        teamRepository.replaceMembers(team.id(), memberIds);
        TeamResponse response = TeamResponse.of(team, memberIds);
        auditLogService.record("TEAM_CREATE", actor.loginId(), "TEAM", team.name(), "SUCCESS", "Team created", httpRequest);
        return ApiResponse.of(response);
    }

    @PutMapping("/{teamId}/members")
    public ApiResponse<TeamResponse> updateMembers(
            @PathVariable("teamId") long teamId,
            @Valid @RequestBody UpdateTeamMembersRequest request,
            HttpServletRequest httpRequest
    ) {
        AuthenticatedUser actor = authContext.currentUser(httpRequest);
        TeamRecord team = findManagedTeam(actor, teamId);
        List<Long> previousMemberIds = teamRepository.findMemberIds(team.id());
        List<Long> memberIds = validateMemberIds(actor, team.organizationId(), request.memberIds());
        teamRepository.replaceMembers(team.id(), memberIds);
        accessKeyService.reconcileActiveKeysForOwners(mergeMemberIds(previousMemberIds, memberIds));
        auditLogService.record("TEAM_MEMBERS_UPDATE", actor.loginId(), "TEAM", String.valueOf(team.id()), "SUCCESS", "Team members updated", httpRequest);
        return ApiResponse.of(TeamResponse.of(team, memberIds));
    }

    @DeleteMapping("/{teamId}")
    public ResponseEntity<Void> delete(
            @PathVariable("teamId") long teamId,
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        TeamRecord team = findManagedTeam(actor, teamId);
        List<Long> memberIds = teamRepository.findMemberIds(team.id());
        int permissionsRemoved = bucketPermissionRepository.deleteBySubject("TEAM", team.id());
        if (permissionsRemoved > 0) {
            accessKeyService.reconcileActiveKeysForOwners(memberIds);
        }
        teamRepository.deleteById(team.id());
        if (permissionsRemoved > 0) {
            auditLogService.record("BUCKET_PERMISSION_SUBJECT_CLEANUP", actor.loginId(), "TEAM", String.valueOf(team.id()), "SUCCESS", "Team bucket permissions deleted: " + permissionsRemoved, request);
        }
        auditLogService.record("TEAM_DELETE", actor.loginId(), "TEAM", team.name(), "SUCCESS", "Team deleted", request);
        return ResponseEntity.noContent().build();
    }


    private Long listOrganizationId(AuthenticatedUser actor, Long requestedOrganizationId) {
        if (actor.isAdmin()) {
            return requestedOrganizationId;
        }
        if (actor.isOrgAdmin() && actor.organizationId() != null) {
            return actor.organizationId();
        }
        throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team access denied.");
    }

    private int normalizeLimit(Integer limit) {
        if (limit == null) {
            return DEFAULT_LIST_LIMIT;
        }
        if (limit < 1 || limit > MAX_LIST_LIMIT) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team list limit must be between 1 and 200.");
        }
        return limit;
    }

    private Long cursorId(String cursor) {
        if (cursor == null || cursor.isBlank()) {
            return null;
        }
        try {
            long parsed = Long.parseLong(cursor.trim());
            if (parsed < 1) {
                throw new NumberFormatException("cursor must be positive");
            }
            return parsed;
        } catch (NumberFormatException exception) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team list cursor is invalid.");
        }
    }

    private TeamRecord findManagedTeam(AuthenticatedUser actor, long teamId) {
        TeamRecord team = teamRepository.findById(teamId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Team not found."));
        if (!canManage(actor, team)) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team management denied.");
        }
        return team;
    }

    private boolean canView(AuthenticatedUser actor, TeamRecord team) {
        return actor.isAdmin()
                || (actor.isOrgAdmin()
                && actor.organizationId() != null
                && actor.organizationId() == team.organizationId());
    }

    private boolean canManage(AuthenticatedUser actor, TeamRecord team) {
        return canView(actor, team);
    }

    private long resolveOrganizationId(AuthenticatedUser actor, Long requestedOrganizationId) {
        if (actor.isAdmin()) {
            if (requestedOrganizationId == null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team organization is required.");
            }
            return requestedOrganizationId;
        }
        if (!actor.isOrgAdmin() || actor.organizationId() == null) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team management denied.");
        }
        if (requestedOrganizationId != null && requestedOrganizationId.longValue() != actor.organizationId()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team organization denied.");
        }
        return actor.organizationId();
    }

    private void validateOrganization(long organizationId) {
        organizationRepository.findById(organizationId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team organization not found."));
    }

    private String normalizedName(String value) {
        String name = value == null ? "" : value.trim();
        if (name.isBlank()) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team name is required.");
        }
        return name;
    }

    private List<Long> validateMemberIds(AuthenticatedUser actor, long organizationId, List<Long> rawMemberIds) {
        if (rawMemberIds == null || rawMemberIds.isEmpty()) {
            return List.of();
        }
        LinkedHashSet<Long> requestedMemberIds = new LinkedHashSet<>();
        for (Long rawMemberId : rawMemberIds) {
            if (rawMemberId != null) {
                requestedMemberIds.add(rawMemberId);
            }
        }
        if (requestedMemberIds.isEmpty()) {
            return List.of();
        }

        List<Long> memberIds = List.copyOf(requestedMemberIds);
        Map<Long, UserAccount> usersById = new HashMap<>();
        for (UserAccount user : userRepository.findByIds(memberIds)) {
            usersById.put(user.id(), user);
        }
        for (Long memberId : memberIds) {
            UserAccount user = usersById.get(memberId);
            if (user == null) {
                throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team member user not found.");
            }
            if (user.organizationId() == null || user.organizationId() != organizationId) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team member organization denied.");
            }
            if (actor.isOrgAdmin() && ("ADMIN".equals(user.role()) || "AUDITOR".equals(user.role()))) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team member role denied.");
            }
        }
        return memberIds;
    }

    private List<Long> mergeMemberIds(List<Long> first, List<Long> second) {
        LinkedHashSet<Long> memberIds = new LinkedHashSet<>();
        if (first != null) {
            memberIds.addAll(first);
        }
        if (second != null) {
            memberIds.addAll(second);
        }
        return List.copyOf(memberIds);
    }
}
