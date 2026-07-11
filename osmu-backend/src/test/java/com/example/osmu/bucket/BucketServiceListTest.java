package com.example.osmu.bucket;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.repository.BucketPermissionRepository;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.bucket.repository.BucketTagRepository;
import com.example.osmu.object.repository.ObjectMetadataRepository;
import com.example.osmu.object.repository.ObjectVersionRepository;
import com.example.osmu.organization.repository.OrganizationRepository;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.quota.repository.QuotaPolicyRepository;
import com.example.osmu.storage.ObjectStorageAdapter;
import com.example.osmu.storageprofile.repository.StorageProfileAssignmentRepository;
import com.example.osmu.user.repository.UserRepository;
import java.util.List;
import org.junit.jupiter.api.Test;

class BucketServiceListTest {

    @Test
    void nonAdminListUsesBulkOwnerAndPermissionQueries() {
        BucketRepository bucketRepository = mock(BucketRepository.class);
        BucketPermissionRepository permissionRepository = mock(BucketPermissionRepository.class);
        TeamRepository teamRepository = mock(TeamRepository.class);
        BucketService service = new BucketService(
                bucketRepository,
                permissionRepository,
                mock(BucketTagRepository.class),
                mock(ObjectStorageAdapter.class),
                mock(ObjectMetadataRepository.class),
                mock(ObjectVersionRepository.class),
                mock(UserRepository.class),
                mock(OrganizationRepository.class),
                teamRepository,
                mock(QuotaPolicyRepository.class),
                mock(StorageProfileAssignmentRepository.class)
        );
        AuthenticatedUser user = new AuthenticatedUser(7L, "member", "USER", 9L);
        List<Long> teamIds = List.of(31L, 32L);
        List<Long> explicitBucketIds = List.of(2L, 4L);
        BucketRecord visibleBucket = mock(BucketRecord.class);

        when(teamRepository.findIdsByMember(user.id())).thenReturn(teamIds);
        when(permissionRepository.findBucketIdsBySubjects(user.id(), user.organizationId(), teamIds))
                .thenReturn(explicitBucketIds);
        when(bucketRepository.findAccessible(user.id(), user.organizationId(), explicitBucketIds))
                .thenReturn(List.of(visibleBucket));

        assertThat(service.list(user)).containsExactly(visibleBucket);

        verify(teamRepository).findIdsByMember(user.id());
        verify(permissionRepository).findBucketIdsBySubjects(user.id(), user.organizationId(), teamIds);
        verify(bucketRepository).findAccessible(user.id(), user.organizationId(), explicitBucketIds);
        verify(bucketRepository, never()).findAll();
        verify(permissionRepository, never()).findByBucketId(anyLong());
    }
}
