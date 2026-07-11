package com.example.osmu.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.ObjectLifecycleRule;
import com.example.osmu.object.ObjectLifecycleRulePageCursor;
import com.example.osmu.object.repository.ObjectLifecycleRuleRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class ObjectLifecycleRuleQueryServiceTest {

    private static final OffsetDateTime BASE_TIME = OffsetDateTime.parse("2026-07-10T09:00:00+09:00");

    @Test
    void listAppliesFiltersAndReturnsCompositeCursorFromVisiblePage() {
        ObjectLifecycleRuleRepository repository = mock(ObjectLifecycleRuleRepository.class);
        ObjectLifecycleRuleQueryService service = new ObjectLifecycleRuleQueryService(
                repository,
                mock(ObjectLifecycleS3XmlService.class)
        );
        ObjectLifecycleRule before = rule(
                "before",
                true,
                5,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "before/",
                30,
                0
        );
        ObjectLifecycleRule first = rule(
                "first",
                true,
                10,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "first/",
                30,
                1
        );
        ObjectLifecycleRule second = rule(
                "second",
                true,
                10,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "second/",
                30,
                2
        );
        ObjectLifecycleRule overfetch = rule(
                "third",
                true,
                20,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "third/",
                30,
                3
        );
        ObjectLifecycleRulePageCursor inputCursor = ObjectLifecycleRulePageCursor.fromRule(before);
        when(repository.findPage(
                true,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                inputCursor,
                3
        )).thenReturn(List.of(first, second, overfetch));

        ListResponse<ObjectLifecycleRule> response = service.list(
                " enabled ",
                "object_version",
                inputCursor.encode(),
                2
        );

        assertThat(response.items()).extracting(ObjectLifecycleRule::ruleId).containsExactly("first", "second");
        assertThat(ObjectLifecycleRulePageCursor.decode(response.nextCursor()))
                .isEqualTo(ObjectLifecycleRulePageCursor.fromRule(second));
        verify(repository).findPage(
                true,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                inputCursor,
                3
        );
    }

    @Test
    void listRejectsInvalidInputsBeforeQueryingRepository() {
        ObjectLifecycleRuleRepository repository = mock(ObjectLifecycleRuleRepository.class);
        ObjectLifecycleRuleQueryService service = new ObjectLifecycleRuleQueryService(
                repository,
                mock(ObjectLifecycleS3XmlService.class)
        );

        assertValidationError(() -> service.list("PENDING", "ALL", null, 50));
        assertValidationError(() -> service.list("ALL", "BUCKET", null, 50));
        assertValidationError(() -> service.list("ALL", "ALL", "not-a-cursor", 50));
        assertValidationError(() -> service.list("ALL", "ALL", null, 0));
        assertValidationError(() -> service.list("ALL", "ALL", null, 201));

        verifyNoInteractions(repository);
    }

    @Test
    void conflictsLoadOnlyEnabledRulesForEachTarget() {
        ObjectLifecycleRuleRepository repository = mock(ObjectLifecycleRuleRepository.class);
        ObjectLifecycleRuleQueryService service = new ObjectLifecycleRuleQueryService(
                repository,
                mock(ObjectLifecycleS3XmlService.class)
        );
        ObjectLifecycleRule trashParent = rule(
                "trash-parent",
                true,
                10,
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                "logs/",
                30,
                1
        );
        ObjectLifecycleRule trashChild = rule(
                "trash-child",
                true,
                20,
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                "logs/raw/",
                7,
                2
        );
        ObjectLifecycleRule versionAlpha = ruleInBucket(
                "version-alpha",
                true,
                5,
                "alpha",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "versions/",
                90,
                3
        );
        ObjectLifecycleRule versionBeta = ruleInBucket(
                "version-beta",
                true,
                10,
                "beta",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "versions/raw/",
                30,
                4
        );
        when(repository.findEnabledByTargetType(ObjectLifecycleRule.TARGET_TRASH_OBJECT))
                .thenReturn(List.of(trashParent, trashChild));
        when(repository.findEnabledByTargetType(ObjectLifecycleRule.TARGET_OBJECT_VERSION))
                .thenReturn(List.of(versionAlpha, versionBeta));

        ObjectLifecycleRuleConflictReportResponse response = service.conflicts();

        assertThat(response.ruleCount()).isEqualTo(4);
        assertThat(response.conflictCount()).isEqualTo(1);
        assertThat(response.conflicts())
                .singleElement()
                .satisfies(conflict -> {
                    assertThat(conflict.targetType()).isEqualTo(ObjectLifecycleRule.TARGET_TRASH_OBJECT);
                    assertThat(conflict.firstRule()).isEqualTo(trashParent);
                    assertThat(conflict.secondRule()).isEqualTo(trashChild);
                });
        verify(repository).findEnabledByTargetType(ObjectLifecycleRule.TARGET_TRASH_OBJECT);
        verify(repository).findEnabledByTargetType(ObjectLifecycleRule.TARGET_OBJECT_VERSION);
    }

    @Test
    void exportUsesExplicitFullExportContract() {
        ObjectLifecycleRuleRepository repository = mock(ObjectLifecycleRuleRepository.class);
        ObjectLifecycleS3XmlService xmlService = mock(ObjectLifecycleS3XmlService.class);
        ObjectLifecycleRuleQueryService service = new ObjectLifecycleRuleQueryService(repository, xmlService);
        List<ObjectLifecycleRule> rules = List.of(rule(
                "export",
                false,
                10,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "",
                30,
                1
        ));
        when(repository.findAllForExport()).thenReturn(rules);
        when(xmlService.exportRules(rules)).thenReturn("<LifecycleConfiguration/>");

        ObjectLifecycleS3XmlResponse response = service.exportS3Xml();

        assertThat(response.ruleCount()).isEqualTo(1);
        assertThat(response.xml()).isEqualTo("<LifecycleConfiguration/>");
        verify(repository).findAllForExport();
        verify(xmlService).exportRules(rules);
    }

    private void assertValidationError(Runnable action) {
        assertThatThrownBy(action::run)
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
    }

    private ObjectLifecycleRule rule(
            String ruleId,
            boolean enabled,
            int priority,
            String targetType,
            String prefix,
            int retentionDays,
            int createdSecond
    ) {
        return ruleInBucket(
                ruleId,
                enabled,
                priority,
                "",
                targetType,
                prefix,
                retentionDays,
                createdSecond
        );
    }

    private ObjectLifecycleRule ruleInBucket(
            String ruleId,
            boolean enabled,
            int priority,
            String bucketName,
            String targetType,
            String prefix,
            int retentionDays,
            int createdSecond
    ) {
        return new ObjectLifecycleRule(
                ruleId,
                ruleId,
                enabled,
                priority,
                bucketName,
                targetType,
                prefix,
                Map.of("stage", "raw"),
                retentionDays,
                100,
                BASE_TIME.plusSeconds(createdSecond),
                BASE_TIME.plusSeconds(createdSecond)
        );
    }
}
