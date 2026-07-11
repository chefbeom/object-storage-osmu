package com.example.osmu.storageexpansion;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.common.api.ListResponse;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.storageexpansion.repository.StorageExpansionExecutionRepository;
import com.example.osmu.storageexpansion.repository.StorageExpansionRequestRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.ObjectProvider;

class StorageExpansionServiceQueryTest {

    private final StorageExpansionRequestRepository repository = mock(StorageExpansionRequestRepository.class);
    private final StorageExpansionExecutionRepository executionRepository = mock(StorageExpansionExecutionRepository.class);
    private final StorageExpansionService service = service(repository, executionRepository);
    private final AuthenticatedUser admin = new AuthenticatedUser(1L, "admin", "ADMIN", null);

    @Test
    void listUsesOpenStatusPageAndReturnsCursorFromVisiblePage() {
        when(repository.findPage(List.of("PLANNED", "APPROVED"), 10L, 3))
                .thenReturn(List.of(request(9L, "PLANNED"), request(8L, "APPROVED"), request(7L, "PLANNED")));

        ListResponse<StorageExpansionRequestResponse> response = service.list(admin, "open", "10", 2);

        assertThat(response.items()).extracting(StorageExpansionRequestResponse::id).containsExactly(9L, 8L);
        assertThat(response.nextCursor()).isEqualTo("8");
        verify(repository).findPage(List.of("PLANNED", "APPROVED"), 10L, 3);
    }

    @Test
    void listRejectsInvalidFiltersBeforeQueryingRepository() {
        assertThatThrownBy(() -> service.list(admin, "RUNNING", null, 50))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
        assertThatThrownBy(() -> service.list(admin, "ALL", "zero", 50))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));
        assertThatThrownBy(() -> service.list(admin, "ALL", null, 201))
                .isInstanceOfSatisfying(ApiException.class, exception ->
                        assertThat(exception.code()).isEqualTo(ApiErrorCode.VALIDATION_ERROR));

        verifyNoInteractions(repository);
    }

    @Test
    void executionHistoryUsesRequestCursorPageAndReturnsNextCursor() {
        when(repository.findById(42L)).thenReturn(Optional.of(request(42L, "APPROVED")));
        when(executionRepository.findPageByRequestId(42L, 10L, 3)).thenReturn(List.of(
                execution(9L, 42L), execution(8L, 42L), execution(7L, 42L)
        ));

        ListResponse<StorageExpansionExecutionResponse> response =
                service.listExecutions(admin, 42L, "10", 2);

        assertThat(response.items()).extracting(StorageExpansionExecutionResponse::id).containsExactly(9L, 8L);
        assertThat(response.nextCursor()).isEqualTo("8");
        verify(executionRepository).findPageByRequestId(42L, 10L, 3);
    }

    @SuppressWarnings("unchecked")
    private StorageExpansionService service(
            StorageExpansionRequestRepository requestRepository,
            StorageExpansionExecutionRepository storageExpansionExecutionRepository
    ) {
        return new StorageExpansionService(
                requestRepository,
                storageExpansionExecutionRepository,
                mock(StorageExpansionDryRunRunner.class),
                mock(StorageExpansionApplyRunner.class),
                mock(StorageExpansionRollbackRunner.class),
                mock(StorageExpansionGitOpsPrRunner.class),
                mock(StorageExpansionPostRunVerifier.class),
                mock(StorageExpansionExecutionLogSanitizer.class),
                mock(ObjectProvider.class),
                mock(StorageExpansionRunnerPreflightService.class),
                true,
                90,
                100
        );
    }

    private StorageExpansionRequestRecord request(long id, String status) {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        return new StorageExpansionRequestRecord(
                id, 100L, 4, 1, 50L, 200L, 100L, status, "reason", "admin",
                null, null, null, now, now
        );
    }

    private StorageExpansionExecutionRecord execution(long id, long requestId) {
        OffsetDateTime now = OffsetDateTime.parse("2026-07-10T00:00:00Z");
        return new StorageExpansionExecutionRecord(
                id, requestId, "HELM_DIFF", "SUCCESS", "helm diff", "clean", null,
                "sha256", 0, false, "notes", "admin", now
        );
    }
}
