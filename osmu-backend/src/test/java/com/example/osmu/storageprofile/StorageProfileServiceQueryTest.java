package com.example.osmu.storageprofile;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.BucketService;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageprofile.repository.StorageProfileAssignmentRepository;
import com.example.osmu.storageprofile.repository.StorageProfileRequestRepository;
import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;

class StorageProfileServiceQueryTest {

    @Test
    void adminListUsesOpenStatusPageAndReturnsCursorFromVisiblePage() {
        StorageProfileRequestRepository requestRepository = mock(StorageProfileRequestRepository.class);
        StorageProfileService service = new StorageProfileService(
                mock(StorageProfileAssignmentRepository.class),
                requestRepository,
                mock(BucketService.class)
        );
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        when(requestRepository.findPage(List.of("PENDING", "APPROVED"), 10L, 3)).thenReturn(List.of(
                request(9L, "alpha", "PENDING"),
                request(8L, "beta", "APPROVED"),
                request(7L, "gamma", "PENDING")
        ));

        ListResponse<StorageProfileRequestResponse> response =
                service.listAdminRequests(admin, "open", "10", 2);

        assertThat(response.items()).extracting(StorageProfileRequestResponse::id).containsExactly(9L, 8L);
        assertThat(response.nextCursor()).isEqualTo("8");
        verify(requestRepository).findPage(List.of("PENDING", "APPROVED"), 10L, 3);
    }

    @Test
    void adminListRejectsInvalidFiltersBeforeQueryingRepository() {
        StorageProfileRequestRepository requestRepository = mock(StorageProfileRequestRepository.class);
        StorageProfileService service = new StorageProfileService(
                mock(StorageProfileAssignmentRepository.class),
                requestRepository,
                mock(BucketService.class)
        );
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);

        assertThatThrownBy(() -> service.listAdminRequests(admin, "RUNNING", null, 50))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
        assertThatThrownBy(() -> service.listAdminRequests(admin, "ALL", "zero", 50))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
        assertThatThrownBy(() -> service.listAdminRequests(admin, "ALL", null, 201))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));

        verifyNoInteractions(requestRepository);
    }

    @Test
    void visibleRequestsUseAccessibleBucketPageAndReturnCursor() {
        StorageProfileRequestRepository requestRepository = mock(StorageProfileRequestRepository.class);
        BucketService bucketService = mock(BucketService.class);
        StorageProfileService service = new StorageProfileService(
                mock(StorageProfileAssignmentRepository.class),
                requestRepository,
                bucketService
        );
        AuthenticatedUser user = new AuthenticatedUser(7L, "developer", "USER", null);
        List<String> visibleBucketNames = List.of("alpha", "beta");
        when(bucketService.list(user)).thenReturn(List.of(bucket(1L, "alpha"), bucket(2L, "beta")));
        when(requestRepository.findPageByBucketNames(visibleBucketNames, 10L, 3)).thenReturn(List.of(
                request(9L, "beta"),
                request(8L, "alpha"),
                request(7L, "beta")
        ));

        ListResponse<StorageProfileRequestResponse> response =
                service.listVisibleRequests(user, null, "10", 2);

        assertThat(response.items()).extracting(StorageProfileRequestResponse::id).containsExactly(9L, 8L);
        assertThat(response.nextCursor()).isEqualTo("8");
        verify(requestRepository).findPageByBucketNames(visibleBucketNames, 10L, 3);
    }

    @Test
    void bucketScopedVisibleRequestsValidateAccessAndUseBucketPage() {
        StorageProfileRequestRepository requestRepository = mock(StorageProfileRequestRepository.class);
        BucketService bucketService = mock(BucketService.class);
        StorageProfileService service = new StorageProfileService(
                mock(StorageProfileAssignmentRepository.class),
                requestRepository,
                bucketService
        );
        AuthenticatedUser user = new AuthenticatedUser(7L, "developer", "USER", null);
        BucketRecord beta = bucket(2L, "beta");
        when(bucketService.get("beta", user)).thenReturn(beta);
        when(requestRepository.findPageByBucketName("beta", 6L, 3)).thenReturn(List.of(
                request(5L, "beta"),
                request(4L, "beta"),
                request(3L, "beta")
        ));

        ListResponse<StorageProfileRequestResponse> response =
                service.listVisibleRequests(user, " beta ", "6", 2);

        assertThat(response.items()).extracting(StorageProfileRequestResponse::id).containsExactly(5L, 4L);
        assertThat(response.nextCursor()).isEqualTo("4");
        verify(bucketService).get("beta", user);
        verify(bucketService, never()).list(user);
        verify(requestRepository).findPageByBucketName("beta", 6L, 3);
    }

    @Test
    void adminVisibleRequestsUseUnfilteredBoundedPage() {
        StorageProfileRequestRepository requestRepository = mock(StorageProfileRequestRepository.class);
        StorageProfileService service = new StorageProfileService(
                mock(StorageProfileAssignmentRepository.class),
                requestRepository,
                mock(BucketService.class)
        );
        AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);
        when(requestRepository.findPage(List.of(), null, 2)).thenReturn(List.of(
                request(2L, "beta"),
                request(1L, "alpha")
        ));

        ListResponse<StorageProfileRequestResponse> response =
                service.listVisibleRequests(admin, null, null, 1);

        assertThat(response.items()).extracting(StorageProfileRequestResponse::id).containsExactly(2L);
        assertThat(response.nextCursor()).isEqualTo("2");
        verify(requestRepository).findPage(List.of(), null, 2);
    }

    private BucketRecord bucket(long id, String name) {
        return new BucketRecord(id, name, "USER", 7L, 1024L, 0L, 0L, OffsetDateTime.now());
    }

    private StorageProfileRequestRecord request(long id, String bucketName) {
        return request(id, bucketName, "PENDING");
    }

    private StorageProfileRequestRecord request(long id, String bucketName, String status) {
        OffsetDateTime now = OffsetDateTime.now();
        return new StorageProfileRequestRecord(
                id,
                bucketName,
                "STANDARD",
                "PERFORMANCE",
                status,
                "reason",
                "developer",
                null,
                null,
                null,
                null,
                null,
                now,
                now
        );
    }
}