package com.example.osmu.object;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.object.repository.InMemoryObjectLifecycleRuleRepository;
import java.time.OffsetDateTime;
import java.util.Map;
import org.junit.jupiter.api.Test;

class InMemoryObjectLifecycleRuleRepositoryTest {

    private static final OffsetDateTime BASE_TIME = OffsetDateTime.parse("2026-07-10T00:00:00Z");

    @Test
    void filteredQueriesPreservePriorityOrder() {
        InMemoryObjectLifecycleRuleRepository repository = new InMemoryObjectLifecycleRuleRepository();
        repository.save(rule("trash-later", true, 200, "alpha", ObjectLifecycleRule.TARGET_TRASH_OBJECT, 3));
        repository.save(rule("trash-first", true, 10, "alpha", ObjectLifecycleRule.TARGET_TRASH_OBJECT, 2));
        repository.save(rule("trash-disabled", false, 1, "alpha", ObjectLifecycleRule.TARGET_TRASH_OBJECT, 1));
        repository.save(rule("version", true, 5, "beta", ObjectLifecycleRule.TARGET_OBJECT_VERSION, 4));

        assertThat(repository.findEnabledByTargetType(ObjectLifecycleRule.TARGET_TRASH_OBJECT))
                .extracting(ObjectLifecycleRule::ruleId)
                .containsExactly("trash-first", "trash-later");
        assertThat(repository.findByBucketName("alpha"))
                .extracting(ObjectLifecycleRule::ruleId)
                .containsExactly("trash-disabled", "trash-first", "trash-later");
    }

    @Test
    void inventoryPageUsesFiltersAndCompositeCursor() {
        InMemoryObjectLifecycleRuleRepository repository = new InMemoryObjectLifecycleRuleRepository();
        ObjectLifecycleRule first = rule(
                "same-a",
                true,
                10,
                "alpha",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                1
        );
        ObjectLifecycleRule second = rule(
                "same-b",
                true,
                10,
                "alpha",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                1
        );
        repository.save(second);
        repository.save(first);
        repository.save(rule(
                "disabled",
                false,
                1,
                "alpha",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                0
        ));
        repository.save(rule(
                "trash",
                true,
                2,
                "alpha",
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                0
        ));

        assertThat(repository.findPage(
                true,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                null,
                1
        )).extracting(ObjectLifecycleRule::ruleId).containsExactly("same-a");
        assertThat(repository.findPage(
                true,
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                ObjectLifecycleRulePageCursor.fromRule(first),
                2
        )).extracting(ObjectLifecycleRule::ruleId).containsExactly("same-b");
    }

    private ObjectLifecycleRule rule(
            String ruleId,
            boolean enabled,
            int priority,
            String bucketName,
            String targetType,
            int createdSecond
    ) {
        return new ObjectLifecycleRule(
                ruleId,
                ruleId,
                enabled,
                priority,
                bucketName,
                targetType,
                "",
                Map.of(),
                30,
                100,
                BASE_TIME.plusSeconds(createdSecond),
                BASE_TIME.plusSeconds(createdSecond)
        );
    }
}