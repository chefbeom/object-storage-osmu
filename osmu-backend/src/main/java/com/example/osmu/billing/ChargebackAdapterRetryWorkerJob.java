package com.example.osmu.billing;

import java.time.OffsetDateTime;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
@ConditionalOnProperty(prefix = "osmu.billing.adapter-retry-worker", name = "enabled", havingValue = "true")
public class ChargebackAdapterRetryWorkerJob {

    private static final Logger log = LoggerFactory.getLogger(ChargebackAdapterRetryWorkerJob.class);

    private final ChargebackAdapterRetryWorkerService retryWorkerService;

    public ChargebackAdapterRetryWorkerJob(ChargebackAdapterRetryWorkerService retryWorkerService) {
        this.retryWorkerService = retryWorkerService;
    }

    @Scheduled(
            initialDelayString = "${osmu.billing.adapter-retry-worker.initial-delay-ms:300000}",
            fixedDelayString = "${osmu.billing.adapter-retry-worker.fixed-delay-ms:900000}"
    )
    public void runDueRetries() {
        try {
            retryWorkerService.runScheduled(OffsetDateTime.now());
        } catch (RuntimeException exception) {
            log.warn("Chargeback adapter retry worker failed.", exception);
        }
    }
}
