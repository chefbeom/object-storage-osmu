package com.example.osmu.billing;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.bucket.BucketRecord;
import com.example.osmu.bucket.repository.BucketRepository;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import com.example.osmu.monitoring.DataFlowEventFilter;
import com.example.osmu.monitoring.DataFlowEventRecord;
import com.example.osmu.monitoring.repository.DataFlowEventRepository;
import com.example.osmu.organization.OrganizationRecord;
import com.example.osmu.organization.repository.OrganizationRepository;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.OffsetDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import org.springframework.stereotype.Service;

@Service
public class ChargebackPreviewService {

    private static final BigDecimal BYTES_PER_GIB = BigDecimal.valueOf(1024L * 1024L * 1024L);
    private static final BigDecimal OPERATIONS_PER_THOUSAND = BigDecimal.valueOf(1000L);

    private final OrganizationRepository organizationRepository;
    private final BucketRepository bucketRepository;
    private final DataFlowEventRepository dataFlowEventRepository;
    private final BillingPricingPolicyService pricingPolicyService;

    public ChargebackPreviewService(
            OrganizationRepository organizationRepository,
            BucketRepository bucketRepository,
            DataFlowEventRepository dataFlowEventRepository,
            BillingPricingPolicyService pricingPolicyService
    ) {
        this.organizationRepository = organizationRepository;
        this.bucketRepository = bucketRepository;
        this.dataFlowEventRepository = dataFlowEventRepository;
        this.pricingPolicyService = pricingPolicyService;
    }

    public ChargebackPreviewResponse preview(AuthenticatedUser actor, ChargebackPreviewRequest request) {
        ChargebackPreviewRequest safeRequest = request == null
                ? new ChargebackPreviewRequest(null, null, null, null, null, null, null, null, 0)
                : request;
        validateWindow(safeRequest.from(), safeRequest.to());
        BillingPricingPolicy pricingPolicy = pricingPolicyService.current();
        ChargebackRateResponse rates = normalizeRates(safeRequest, pricingPolicy);
        String currency = BillingPricingPolicyService.normalizeCurrency(safeRequest.currency(), pricingPolicy.currency());
        int eventScanLimit = BillingPricingPolicyService.normalizeEventScanLimit(safeRequest.eventScanLimit(), pricingPolicy.eventScanLimit());
        List<OrganizationRecord> organizations = visibleOrganizations(actor);
        List<BucketRecord> buckets = bucketRepository.findAll();

        Map<Long, OrganizationAccumulator> organizationAccumulators = new LinkedHashMap<>();
        for (OrganizationRecord organization : organizations) {
            organizationAccumulators.put(organization.id(), new OrganizationAccumulator(organization));
        }

        Map<String, Long> bucketOrganizationIds = new LinkedHashMap<>();
        for (BucketRecord bucket : buckets) {
            if (!"ORG".equals(bucket.ownerType())) {
                continue;
            }
            OrganizationAccumulator accumulator = organizationAccumulators.get(bucket.ownerId());
            if (accumulator == null) {
                continue;
            }
            bucketOrganizationIds.put(bucket.name(), bucket.ownerId());
            accumulator.recordBucket(bucket);
        }

        List<DataFlowEventRecord> events = dataFlowEventRepository.find(
                new DataFlowEventFilter(null, null, null, null, null, safeRequest.from(), safeRequest.to()),
                eventScanLimit
        );
        for (DataFlowEventRecord event : events) {
            Long organizationId = bucketOrganizationIds.get(event.bucketName());
            if (organizationId == null) {
                continue;
            }
            OrganizationAccumulator accumulator = organizationAccumulators.get(organizationId);
            if (accumulator != null) {
                accumulator.recordEvent(event);
            }
        }

        List<ChargebackOrganizationPreviewResponse> previews = organizationAccumulators.values().stream()
                .map(accumulator -> accumulator.snapshot(rates))
                .toList();

        Totals totals = new Totals();
        for (ChargebackOrganizationPreviewResponse preview : previews) {
            totals.record(preview);
        }

        return new ChargebackPreviewResponse(
                currency,
                safeRequest.from(),
                safeRequest.to(),
                rates,
                eventScanLimit,
                events.size(),
                previews.size(),
                totals.bucketCount,
                totals.usedBytes,
                totals.ingressBytes,
                totals.egressBytes,
                totals.internalBytes,
                totals.billableOperationCount,
                totals.failedOperationCount,
                totals.cancelledOperationCount,
                money(totals.estimatedTotalCost),
                previews,
                OffsetDateTime.now()
        );
    }

    public String exportCsv(AuthenticatedUser actor, ChargebackPreviewRequest request) {
        ChargebackPreviewResponse preview = preview(actor, request);
        ChargebackRateResponse rates = preview.rates();
        BigDecimal totalStorageCost = sumCost(preview, "storage");
        BigDecimal totalIngressCost = sumCost(preview, "ingress");
        BigDecimal totalEgressCost = sumCost(preview, "egress");
        BigDecimal totalInternalCost = sumCost(preview, "internal");
        BigDecimal totalOperationCost = sumCost(preview, "operation");
        long totalObjectCount = preview.organizations().stream()
                .mapToLong(ChargebackOrganizationPreviewResponse::objectCount)
                .sum();

        StringBuilder csv = new StringBuilder("rowType,currency,from,to,generatedAt,eventScanLimit,scannedEventCount,organizationCount,organizationId,organizationName,bucketCount,objectCount,usedBytes,ingressBytes,egressBytes,internalBytes,billableOperationCount,failedOperationCount,cancelledOperationCount,storageGbMonthRate,ingressGbRate,egressGbRate,internalGbRate,operationThousandRate,projectedStorageCost,ingressCost,egressCost,internalCost,operationCost,estimatedTotalCost\n");
        appendCsvRow(
                csv,
                "TOTAL",
                preview.currency(),
                preview.from(),
                preview.to(),
                preview.generatedAt(),
                preview.eventScanLimit(),
                preview.scannedEventCount(),
                preview.organizationCount(),
                "",
                "TOTAL",
                preview.bucketCount(),
                totalObjectCount,
                preview.usedBytes(),
                preview.ingressBytes(),
                preview.egressBytes(),
                preview.internalBytes(),
                preview.billableOperationCount(),
                preview.failedOperationCount(),
                preview.cancelledOperationCount(),
                rates.storageGbMonthRate(),
                rates.ingressGbRate(),
                rates.egressGbRate(),
                rates.internalGbRate(),
                rates.operationThousandRate(),
                totalStorageCost,
                totalIngressCost,
                totalEgressCost,
                totalInternalCost,
                totalOperationCost,
                preview.estimatedTotalCost()
        );
        for (ChargebackOrganizationPreviewResponse organization : preview.organizations()) {
            appendCsvRow(
                    csv,
                    "ORGANIZATION",
                    preview.currency(),
                    preview.from(),
                    preview.to(),
                    preview.generatedAt(),
                    preview.eventScanLimit(),
                    preview.scannedEventCount(),
                    "",
                    organization.organizationId(),
                    organization.organizationName(),
                    organization.bucketCount(),
                    organization.objectCount(),
                    organization.usedBytes(),
                    organization.ingressBytes(),
                    organization.egressBytes(),
                    organization.internalBytes(),
                    organization.billableOperationCount(),
                    organization.failedOperationCount(),
                    organization.cancelledOperationCount(),
                    rates.storageGbMonthRate(),
                    rates.ingressGbRate(),
                    rates.egressGbRate(),
                    rates.internalGbRate(),
                    rates.operationThousandRate(),
                    organization.projectedStorageCost(),
                    organization.ingressCost(),
                    organization.egressCost(),
                    organization.internalCost(),
                    organization.operationCost(),
                    organization.estimatedTotalCost()
            );
        }
        return csv.toString();
    }

    public ChargebackAlertResponse alerts(AuthenticatedUser actor, ChargebackPreviewRequest request) {
        ChargebackPreviewResponse preview = preview(actor, request);
        BillingPricingPolicy pricingPolicy = pricingPolicyService.current();
        BigDecimal warningAmount = money(pricingPolicy.warningAmount());
        BigDecimal criticalAmount = money(pricingPolicy.criticalAmount());
        List<ChargebackAlertOrganizationResponse> alerts = preview.organizations().stream()
                .map(organization -> alertFor(organization, warningAmount, criticalAmount))
                .filter(alert -> alert != null)
                .toList();
        return new ChargebackAlertResponse(
                preview.currency(),
                warningAmount,
                criticalAmount,
                alerts.size(),
                alerts.stream().filter(alert -> "WARNING".equals(alert.severity())).count(),
                alerts.stream().filter(alert -> "CRITICAL".equals(alert.severity())).count(),
                alerts,
                OffsetDateTime.now()
        );
    }

    private List<OrganizationRecord> visibleOrganizations(AuthenticatedUser actor) {
        if (actor == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
        }
        if (actor.isAdmin()) {
            return organizationRepository.findAll();
        }
        if (actor.isOrgAdmin() && actor.organizationId() != null) {
            OrganizationRecord organization = organizationRepository.findById(actor.organizationId())
                    .orElseThrow(() -> new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Organization access denied."));
            return List.of(organization);
        }
        throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Chargeback preview access denied.");
    }

    private void validateWindow(OffsetDateTime from, OffsetDateTime to) {
        if (from != null && to != null && from.isAfter(to)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "from must be earlier than or equal to to.");
        }
    }

    private ChargebackRateResponse normalizeRates(ChargebackPreviewRequest request, BillingPricingPolicy pricingPolicy) {
        return new ChargebackRateResponse(
                BillingPricingPolicyService.normalizeRate(request.storageGbMonthRate(), pricingPolicy.storageGbMonthRate(), "storageGbMonthRate"),
                BillingPricingPolicyService.normalizeRate(request.ingressGbRate(), pricingPolicy.ingressGbRate(), "ingressGbRate"),
                BillingPricingPolicyService.normalizeRate(request.egressGbRate(), pricingPolicy.egressGbRate(), "egressGbRate"),
                BillingPricingPolicyService.normalizeRate(request.internalGbRate(), pricingPolicy.internalGbRate(), "internalGbRate"),
                BillingPricingPolicyService.normalizeRate(request.operationThousandRate(), pricingPolicy.operationThousandRate(), "operationThousandRate")
        );
    }

    private static BigDecimal costForBytes(BigDecimal rate, long bytes) {
        if (bytes <= 0 || rate.compareTo(BigDecimal.ZERO) == 0) {
            return money(BigDecimal.ZERO);
        }
        return money(rate.multiply(BigDecimal.valueOf(bytes)).divide(BYTES_PER_GIB, 6, RoundingMode.HALF_UP));
    }

    private static BigDecimal costForOperations(BigDecimal rate, long count) {
        if (count <= 0 || rate.compareTo(BigDecimal.ZERO) == 0) {
            return money(BigDecimal.ZERO);
        }
        return money(rate.multiply(BigDecimal.valueOf(count)).divide(OPERATIONS_PER_THOUSAND, 6, RoundingMode.HALF_UP));
    }

    private static BigDecimal money(BigDecimal value) {
        return value.setScale(6, RoundingMode.HALF_UP);
    }

    private static BigDecimal sumCost(ChargebackPreviewResponse preview, String field) {
        BigDecimal total = BigDecimal.ZERO;
        for (ChargebackOrganizationPreviewResponse organization : preview.organizations()) {
            total = switch (field) {
                case "storage" -> total.add(organization.projectedStorageCost());
                case "ingress" -> total.add(organization.ingressCost());
                case "egress" -> total.add(organization.egressCost());
                case "internal" -> total.add(organization.internalCost());
                case "operation" -> total.add(organization.operationCost());
                default -> total;
            };
        }
        return money(total);
    }

    private static void appendCsvRow(StringBuilder csv, Object... values) {
        for (int index = 0; index < values.length; index += 1) {
            if (index > 0) {
                csv.append(',');
            }
            csv.append(csvCell(values[index]));
        }
        csv.append('\n');
    }

    private static String csvCell(Object value) {
        String text = value == null ? "" : String.valueOf(value);
        return "\"" + text.replace("\"", "\"\"").replace("\r", " ").replace("\n", " ") + "\"";
    }

    private static ChargebackAlertOrganizationResponse alertFor(
            ChargebackOrganizationPreviewResponse organization,
            BigDecimal warningAmount,
            BigDecimal criticalAmount
    ) {
        BigDecimal estimatedCost = money(organization.estimatedTotalCost());
        boolean critical = criticalAmount.compareTo(BigDecimal.ZERO) > 0 && estimatedCost.compareTo(criticalAmount) >= 0;
        boolean warning = warningAmount.compareTo(BigDecimal.ZERO) > 0 && estimatedCost.compareTo(warningAmount) >= 0;
        if (!critical && !warning) {
            return null;
        }
        return new ChargebackAlertOrganizationResponse(
                organization.organizationId(),
                organization.organizationName(),
                critical ? "CRITICAL" : "WARNING",
                estimatedCost,
                warningAmount,
                criticalAmount
        );
    }

    private static final class OrganizationAccumulator {
        private final OrganizationRecord organization;
        private long bucketCount;
        private long objectCount;
        private long usedBytes;
        private long ingressBytes;
        private long egressBytes;
        private long internalBytes;
        private long billableOperationCount;
        private long failedOperationCount;
        private long cancelledOperationCount;

        private OrganizationAccumulator(OrganizationRecord organization) {
            this.organization = organization;
        }

        private void recordBucket(BucketRecord bucket) {
            bucketCount += 1;
            objectCount += bucket.objectCount();
            usedBytes += Math.max(0L, bucket.usedBytes());
        }

        private void recordEvent(DataFlowEventRecord event) {
            if ("FAILED".equalsIgnoreCase(event.status()) || "FAILURE".equalsIgnoreCase(event.eventType())) {
                failedOperationCount += 1;
                return;
            }
            if ("CANCELLED".equalsIgnoreCase(event.status()) || "CANCEL".equalsIgnoreCase(event.eventType())) {
                cancelledOperationCount += 1;
                return;
            }
            if (!"SUCCESS".equalsIgnoreCase(event.status())) {
                return;
            }
            billableOperationCount += 1;
            long bytes = Math.max(0L, event.sizeBytes());
            String direction = event.direction() == null ? "" : event.direction().toUpperCase(Locale.ROOT);
            switch (direction) {
                case "INGRESS" -> ingressBytes += bytes;
                case "EGRESS" -> egressBytes += bytes;
                case "INTERNAL" -> internalBytes += bytes;
                default -> {
                    // Metadata/control events are billable operations but do not carry bytes.
                }
            }
        }

        private ChargebackOrganizationPreviewResponse snapshot(ChargebackRateResponse rates) {
            BigDecimal projectedStorageCost = costForBytes(rates.storageGbMonthRate(), usedBytes);
            BigDecimal ingressCost = costForBytes(rates.ingressGbRate(), ingressBytes);
            BigDecimal egressCost = costForBytes(rates.egressGbRate(), egressBytes);
            BigDecimal internalCost = costForBytes(rates.internalGbRate(), internalBytes);
            BigDecimal operationCost = costForOperations(rates.operationThousandRate(), billableOperationCount);
            BigDecimal total = money(projectedStorageCost
                    .add(ingressCost)
                    .add(egressCost)
                    .add(internalCost)
                    .add(operationCost));
            return new ChargebackOrganizationPreviewResponse(
                    organization.id(),
                    organization.name(),
                    bucketCount,
                    objectCount,
                    usedBytes,
                    ingressBytes,
                    egressBytes,
                    internalBytes,
                    billableOperationCount,
                    failedOperationCount,
                    cancelledOperationCount,
                    projectedStorageCost,
                    ingressCost,
                    egressCost,
                    internalCost,
                    operationCost,
                    total
            );
        }
    }

    private static final class Totals {
        private long bucketCount;
        private long usedBytes;
        private long ingressBytes;
        private long egressBytes;
        private long internalBytes;
        private long billableOperationCount;
        private long failedOperationCount;
        private long cancelledOperationCount;
        private BigDecimal estimatedTotalCost = money(BigDecimal.ZERO);

        private void record(ChargebackOrganizationPreviewResponse preview) {
            bucketCount += preview.bucketCount();
            usedBytes += preview.usedBytes();
            ingressBytes += preview.ingressBytes();
            egressBytes += preview.egressBytes();
            internalBytes += preview.internalBytes();
            billableOperationCount += preview.billableOperationCount();
            failedOperationCount += preview.failedOperationCount();
            cancelledOperationCount += preview.cancelledOperationCount();
            estimatedTotalCost = estimatedTotalCost.add(preview.estimatedTotalCost());
        }
    }
}
