package com.example.osmu.accesskey;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.example.osmu.accesskey.repository.InMemoryAccessKeyRepository;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class AccessKeyProvisioningRecoveryTest {

    @Test
    void reconcileMarksKeyInactiveWhenPolicySyncAndCleanupFail() {
        InMemoryAccessKeyRepository accessKeyRepository = new InMemoryAccessKeyRepository();
        accessKeyRepository.save(accessKeyWithScope(
                1L,
                42L,
                "sync-fail-key",
                List.of(new AccessKeyBucketScope("reconcile-bucket", List.of("READ", "WRITE")))
        ));
        UserRepository userRepository = mock(UserRepository.class);
        when(userRepository.findById(42L)).thenReturn(Optional.of(new UserAccount(
                42L,
                "sync-user",
                "sync-user@example.com",
                "Sync User",
                "hash",
                "USER",
                "ACTIVE",
                null
        )));
        BucketService bucketService = mock(BucketService.class);
        doThrow(new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Bucket write denied."))
                .when(bucketService)
                .assertCanWrite(eq("reconcile-bucket"), any(AuthenticatedUser.class));

        AccessKeyService service = new AccessKeyService(
                accessKeyRepository,
                bucketService,
                userRepository,
                mock(TeamRepository.class),
                new S3AccessPolicyGenerator(),
                new SyncAndDeactivateFailingProvisioner(),
                new AccessKeySecretCipher("unit-test-access-key-encryption-key-32+"),
                300L
        );

        assertThatThrownBy(() -> service.reconcileActiveKeysForOwners(List.of(42L)))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("policy sync failed")
                .satisfies(exception -> assertThat(exception.getSuppressed())
                        .extracting(Throwable::getMessage)
                        .contains("policy cleanup failed"));
        assertThat(accessKeyRepository.findRecordById(1L))
                .hasValueSatisfying(record -> assertThat(record.status()).isEqualTo("INACTIVE"));
    }

    private AccessKeyEntity accessKeyWithScope(
            long id,
            long ownerId,
            String name,
            List<AccessKeyBucketScope> bucketScopes
    ) {
        return new AccessKeyEntity(
                id,
                ownerId,
                name,
                "osmu_" + id,
                "secret-hash",
                "secret-ciphertext",
                null,
                null,
                null,
                bucketScopes.stream().map(AccessKeyBucketScope::bucketName).toList(),
                bucketScopes.stream()
                        .flatMap(scope -> scope.permissions().stream())
                        .distinct()
                        .toList(),
                bucketScopes,
                "ACTIVE",
                OffsetDateTime.now(),
                null,
                null,
                0L
        );
    }

    private static class SyncAndDeactivateFailingProvisioner implements S3AccessPolicyProvisioner {

        @Override
        public void provision(AccessKeyRecord accessKey, String secretKey, S3AccessPolicy policy) {
        }

        @Override
        public void rotateSecret(AccessKeyRecord accessKey, String secretKey) {
        }

        @Override
        public void syncPolicy(AccessKeyRecord accessKey, S3AccessPolicy policy) {
            throw new IllegalStateException("policy sync failed");
        }

        @Override
        public void deactivate(AccessKeyRecord accessKey) {
            throw new IllegalStateException("policy cleanup failed");
        }

        @Override
        public boolean isHealthy() {
            return false;
        }
    }
}
