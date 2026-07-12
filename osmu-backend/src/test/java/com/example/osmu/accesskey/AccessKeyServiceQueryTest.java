package com.example.osmu.accesskey;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.accesskey.repository.AccessKeyRepository;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.organization.repository.TeamRepository;
import com.example.osmu.user.repository.UserRepository;
import java.util.List;
import org.junit.jupiter.api.Test;

class AccessKeyServiceQueryTest {

    @Test
    void nonAdminListLoadsOnlyTheCurrentOwnersKeys() {
        AccessKeyRepository accessKeyRepository = mock(AccessKeyRepository.class);
        when(accessKeyRepository.findRecordsByOwnerId(7L)).thenReturn(List.of());
        AccessKeyService service = new AccessKeyService(
                accessKeyRepository,
                mock(BucketService.class),
                mock(UserRepository.class),
                mock(TeamRepository.class),
                new S3AccessPolicyGenerator(),
                mock(S3AccessPolicyProvisioner.class),
                new AccessKeySecretCipher("unit-test-access-key-encryption-key-32+"),
                300L
        );

        assertThat(service.list(new com.example.osmu.auth.AuthenticatedUser(7L, "developer", "USER", null))).isEmpty();

        verify(accessKeyRepository).findRecordsByOwnerId(7L);
        verify(accessKeyRepository, never()).findAllRecords();
    }

    @Test
    void organizationReconciliationLoadsOnlyIndexedUserIds() {
        AccessKeyRepository accessKeyRepository = mock(AccessKeyRepository.class);
        UserRepository userRepository = mock(UserRepository.class);
        when(userRepository.findIdsByOrganizationId(7L)).thenReturn(List.of(11L, 12L));
        when(accessKeyRepository.findRecordsByOwnerIds(List.of(11L, 12L))).thenReturn(List.of());
        AccessKeyService service = new AccessKeyService(
                accessKeyRepository,
                mock(BucketService.class),
                userRepository,
                mock(TeamRepository.class),
                new S3AccessPolicyGenerator(),
                mock(S3AccessPolicyProvisioner.class),
                new AccessKeySecretCipher("unit-test-access-key-encryption-key-32+"),
                300L
        );

        assertThat(service.reconcileActiveKeysForSubject("ORGANIZATION", 7L)).isZero();

        verify(userRepository).findIdsByOrganizationId(7L);
        verify(accessKeyRepository).findRecordsByOwnerIds(List.of(11L, 12L));
        verify(accessKeyRepository, never()).findRecordsByOwnerId(anyLong());
    }
}