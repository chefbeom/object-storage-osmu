package com.example.osmu.admin;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.example.osmu.audit.AuditLogService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.common.api.ApiResponse;
import com.example.osmu.object.ObjectShareLinkAnalytics;
import com.example.osmu.object.ObjectSharePolicyService;
import com.example.osmu.object.repository.ObjectShareLinkRepository;
import java.util.List;
import org.junit.jupiter.api.Test;

class AdminObjectSharePolicyControllerQueryTest {

    @Test
    void analyticsDelegatesNormalizedFiltersAndLimitWithoutLoadingAllLinks() {
        ObjectShareLinkRepository repository = mock(ObjectShareLinkRepository.class);
        when(repository.analytics("bucket-one", "ACTIVE", 5))
                .thenReturn(new ObjectShareLinkAnalytics(3L, 3L, 0L, 0L, 0L, 1L, 1L, 7L, null, List.of()));
        AdminObjectSharePolicyController controller = new AdminObjectSharePolicyController(
                mock(ObjectSharePolicyService.class),
                repository,
                mock(AuditLogService.class),
                mock(AuthContext.class)
        );

        ApiResponse<ObjectShareAnalyticsResponse> response = controller.analytics(5, " Bucket-One ", " active ");

        assertThat(response.data().totalLinks()).isEqualTo(3L);
        assertThat(response.data().activeLinks()).isEqualTo(3L);
        verify(repository).analytics("bucket-one", "ACTIVE", 5);
    }
}