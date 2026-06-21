package com.example.osmu.storage.minio;

import com.example.osmu.object.ObjectLifecycleRule;
import io.minio.messages.AndOperator;
import io.minio.messages.Expiration;
import io.minio.messages.LifecycleConfiguration;
import io.minio.messages.LifecycleRule;
import io.minio.messages.NoncurrentVersionExpiration;
import io.minio.messages.RuleFilter;
import io.minio.messages.Status;
import io.minio.messages.Tag;
import java.time.ZonedDateTime;
import java.util.List;
import java.util.Map;

final class MinioBucketLifecycleMapper {

    private MinioBucketLifecycleMapper() {
    }

    static LifecycleConfiguration toConfiguration(List<ObjectLifecycleRule> rules) {
        return new LifecycleConfiguration(rules.stream()
                .map(MinioBucketLifecycleMapper::toRule)
                .toList());
    }

    static boolean requiresVersioning(List<ObjectLifecycleRule> rules) {
        return rules.stream()
                .anyMatch(rule -> rule.enabled()
                        && ObjectLifecycleRule.TARGET_OBJECT_VERSION.equals(rule.targetType()));
    }

    private static LifecycleRule toRule(ObjectLifecycleRule rule) {
        Status status = rule.enabled() ? Status.ENABLED : Status.DISABLED;
        RuleFilter filter = toFilter(rule);
        if (ObjectLifecycleRule.TARGET_OBJECT_VERSION.equals(rule.targetType())) {
            return new LifecycleRule(
                    status,
                    null,
                    null,
                    filter,
                    rule.name(),
                    new NoncurrentVersionExpiration(rule.retentionDays()),
                    null,
                    null
            );
        }
        return new LifecycleRule(
                status,
                null,
                new Expiration((ZonedDateTime) null, rule.retentionDays(), null),
                filter,
                rule.name(),
                null,
                null,
                null
        );
    }

    private static RuleFilter toFilter(ObjectLifecycleRule rule) {
        Map<String, String> tags = rule.tags();
        if (tags.isEmpty()) {
            return new RuleFilter(rule.prefix());
        }
        if (rule.prefix().isBlank() && tags.size() == 1) {
            Map.Entry<String, String> tag = tags.entrySet().iterator().next();
            return new RuleFilter(new Tag(tag.getKey(), tag.getValue()));
        }
        return new RuleFilter(new AndOperator(rule.prefix(), tags));
    }
}
