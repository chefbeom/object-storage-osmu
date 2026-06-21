package com.example.osmu.bucket;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.bucket.repository.BucketTagRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.quota.repository.QuotaPolicyRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.storageprofile.repository.StorageProfileAssignmentRepository;
import com.example.osmu.user.UserAccount;
import com.example.osmu.user.repository.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.Test;

class BucketServiceStorageFailureTest {

    @Test
    void createBucketStorageRuntimeFailureReturnsStorageErrorBeforeSavingMetadata() {
        BucketRepository bucketRepository = mock(BucketRepository.class);
        ObjectStorageAdapter storageAdapter = mock(ObjectStorageAdapter.class);
        UserRepository userRepository = mock(UserRepository.class);
        BucketService bucketService = new BucketService(
                bucketRepository,
                mock(BucketPermissionRepository.class),
                mock(BucketTagRepository.class),
                storageAdapter,
                mock(ObjectMetadataRepository.class),
                mock(ObjectVersionRepository.class),
                userRepository,
                mock(OrganizationRepository.class),
                mock(TeamRepository.class),
                mock(QuotaPolicyRepository.class),
                mock(StorageProfileAssignmentRepository.class)
        );
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        when(userRepository.findById(1L)).thenReturn(Optional.of(new UserAccount(
                1L,
                "admin",
                "admin@example.com",
                "Admin",
                "hash",
                "ADMIN",
                "ACTIVE",
                null
        )));
        when(bucketRepository.existsByName("storage-down-bucket")).thenReturn(false);
        when(bucketRepository.nextId()).thenReturn(1L);
        doThrow(new IllegalStateException("minio offline"))
                .when(storageAdapter)
                .createBucket("storage-down-bucket");

        assertThatThrownBy(() -> bucketService.create(
                new CreateBucketRequest("storage-down-bucket", 1024L, null, null),
                admin
        ))
                .isInstanceOf(ApiException.class)
                .satisfies(exception -> {
                    ApiException apiException = (ApiException) exception;
                    assertThat(apiException.code()).isEqualTo(ApiErrorCode.STORAGE_ERROR);
                    assertThat(apiException.getMessage()).contains("Object storage bucket create failed: minio offline");
                });
        verify(bucketRepository, never()).save(org.mockito.ArgumentMatchers.any(BucketRecord.class));
    }
}
