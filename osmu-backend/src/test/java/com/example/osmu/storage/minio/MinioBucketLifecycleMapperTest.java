package com.example.osmu.storage.minio;

import static org.assertj.core.api.Assertions.assertThat;

import com.example.osmu.object.ObjectLifecycleRule;
import io.minio.messages.LifecycleConfiguration;
import io.minio.messages.LifecycleRule;
import io.minio.messages.Status;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;

class MinioBucketLifecycleMapperTest {

    @Test
    void mapsOsmuRulesToMinioLifecycleConfiguration() {
        OffsetDateTime now = OffsetDateTime.now();
        ObjectLifecycleRule trashRule = new ObjectLifecycleRule(
                "rule-1",
                "Delete tmp",
                true,
                10,
                "media",
                ObjectLifecycleRule.TARGET_TRASH_OBJECT,
                "tmp/",
                Map.of(),
                7,
                100,
                now,
                now
        );
        ObjectLifecycleRule versionRule = new ObjectLifecycleRule(
                "rule-2",
                "Expire old versions",
                true,
                20,
                "media",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "videos/",
                Map.of("stage", "raw"),
                30,
                100,
                now,
                now
        );

        LifecycleConfiguration configuration = MinioBucketLifecycleMapper.toConfiguration(List.of(trashRule, versionRule));

        assertThat(configuration.rules()).hasSize(2);
        LifecycleRule first = configuration.rules().get(0);
        assertThat(first.id()).isEqualTo("Delete tmp");
        assertThat(first.status()).isEqualTo(Status.ENABLED);
        assertThat(first.filter().prefix()).isEqualTo("tmp/");
        assertThat(first.expiration().days()).isEqualTo(7);
        assertThat(first.noncurrentVersionExpiration()).isNull();

        LifecycleRule second = configuration.rules().get(1);
        assertThat(second.id()).isEqualTo("Expire old versions");
        assertThat(second.filter().andOperator().prefix()).isEqualTo("videos/");
        assertThat(second.filter().andOperator().tags()).containsEntry("stage", "raw");
        assertThat(second.expiration()).isNull();
        assertThat(second.noncurrentVersionExpiration().noncurrentDays()).isEqualTo(30);
        assertThat(MinioBucketLifecycleMapper.requiresVersioning(List.of(trashRule, versionRule))).isTrue();
    }

    @Test
    void disabledNoncurrentRuleDoesNotRequireVersioningToggle() {
        OffsetDateTime now = OffsetDateTime.now();
        ObjectLifecycleRule disabledRule = new ObjectLifecycleRule(
                "rule-1",
                "Disabled old versions",
                false,
                10,
                "media",
                ObjectLifecycleRule.TARGET_OBJECT_VERSION,
                "",
                Map.of(),
                30,
                100,
                now,
                now
        );

        assertThat(MinioBucketLifecycleMapper.requiresVersioning(List.of(disabledRule))).isFalse();
    }
}
