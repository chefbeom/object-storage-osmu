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
import java.util.LinkedHashSet;
import java.util.List;
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
            HttpServletRequest request
    ) {
        AuthenticatedUser actor = authContext.currentUser(request);
        List<TeamResponse> teams = teamRepository.findAll().stream()
                .filter(team -> canView(actor, team))
                .filter(team -> organizationId == null || team.organizationId() == organizationId)
                .map(this::toResponse)
                .toList();
        return ListResponse.of(teams);
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

        OffsetDateTime now = OffsetDateTime.now();
        TeamRecord team = teamRepository.save(new TeamRecord(
                teamRepository.nextId(),
                organizationId,
                name,
                request.description() == null ? "" : request.description().trim(),
                now,
                now
        ));
        List<Long> memberIds = validateMemberIds(actor, team, request.memberIds());
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
        List<Long> memberIds = validateMemberIds(actor, team, request.memberIds());
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

    private TeamResponse toResponse(TeamRecord team) {
        return TeamResponse.of(team, teamRepository.findMemberIds(team.id()));
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

    private List<Long> validateMemberIds(AuthenticatedUser actor, TeamRecord team, List<Long> rawMemberIds) {
        if (rawMemberIds == null || rawMemberIds.isEmpty()) {
            return List.of();
        }
        LinkedHashSet<Long> memberIds = new LinkedHashSet<>();
        for (Long rawMemberId : rawMemberIds) {
            if (rawMemberId == null) {
                continue;
            }
            UserAccount user = userRepository.findById(rawMemberId)
                    .orElseThrow(() -> new ApiException(ApiErrorCode.VALIDATION_ERROR, "Team member user not found."));
            if (user.organizationId() == null || user.organizationId() != team.organizationId()) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team member organization denied.");
            }
            if (actor.isOrgAdmin() && ("ADMIN".equals(user.role()) || "AUDITOR".equals(user.role()))) {
                throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Team member role denied.");
            }
            memberIds.add(user.id());
        }
        return List.copyOf(memberIds);
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
