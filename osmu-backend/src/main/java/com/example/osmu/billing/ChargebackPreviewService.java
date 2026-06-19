package com.example.osmu.billing;

import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.billing.repository.ChargebackInvoiceDraftRepository;
import com.example.osmu.billing.repository.ChargebackNotificationDeliveryRepository;
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
import java.time.format.DateTimeFormatter;
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
    private final ChargebackNotificationDeliveryRepository notificationDeliveryRepository;
    private final ChargebackInvoiceDraftRepository invoiceDraftRepository;

    public ChargebackPreviewService(
            OrganizationRepository organizationRepository,
            BucketRepository bucketRepository,
            DataFlowEventRepository dataFlowEventRepository,
            BillingPricingPolicyService pricingPolicyService,
            ChargebackNotificationDeliveryRepository notificationDeliveryRepository,
            ChargebackInvoiceDraftRepository invoiceDraftRepository
    ) {
        this.organizationRepository = organizationRepository;
        this.bucketRepository = bucketRepository;
        this.dataFlowEventRepository = dataFlowEventRepository;
        this.pricingPolicyService = pricingPolicyService;
        this.notificationDeliveryRepository = notificationDeliveryRepository;
        this.invoiceDraftRepository = invoiceDraftRepository;
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

    public String exportInvoiceDraftCsv(AuthenticatedUser actor, ChargebackPreviewRequest request) {
        ChargebackPreviewResponse preview = preview(actor, request);
        StringBuilder csv = new StringBuilder("rowType,invoiceNumber,invoiceStatus,currency,from,to,generatedAt,organizationId,organizationName,bucketCount,objectCount,usedBytes,storageCost,trafficCost,operationCost,estimatedTotalCost,note\n");
        for (ChargebackOrganizationPreviewResponse organization : preview.organizations()) {
            BigDecimal trafficCost = money(organization.ingressCost()
                    .add(organization.egressCost())
                    .add(organization.internalCost()));
            appendCsvRow(
                    csv,
                    "DRAFT_INVOICE",
                    draftInvoiceNumber(preview, organization),
                    "DRAFT",
                    preview.currency(),
                    preview.from(),
                    preview.to(),
                    preview.generatedAt(),
                    organization.organizationId(),
                    organization.organizationName(),
                    organization.bucketCount(),
                    organization.objectCount(),
                    organization.usedBytes(),
                    organization.projectedStorageCost(),
                    trafficCost,
                    organization.operationCost(),
                    organization.estimatedTotalCost(),
                    "Preview only - not a final invoice or approved commercial price list."
            );
        }
        return csv.toString();
    }

    public ChargebackInvoiceDraftCreateResponse persistInvoiceDrafts(
            AuthenticatedUser actor,
            ChargebackPreviewRequest request,
            String reason
    ) {
        requireAdmin(actor, "Chargeback invoice draft persistence requires ADMIN.");
        ChargebackPreviewResponse preview = preview(actor, request);
        OffsetDateTime now = OffsetDateTime.now();
        String normalizedReason = normalizeReason(reason);
        List<ChargebackInvoiceDraftRecord> records = preview.organizations().stream()
                .map(organization -> invoiceDraftRecord(preview, organization, actor.loginId(), normalizedReason, now))
                .toList();
        List<ChargebackInvoiceDraftRecord> saved = invoiceDraftRepository.saveAll(records);
        return new ChargebackInvoiceDraftCreateResponse(
                "DRAFT_REVIEW",
                "DRAFT_REVIEW",
                false,
                false,
                saved.size(),
                saved.stream().map(ChargebackPreviewService::invoiceResponse).toList(),
                OffsetDateTime.now(),
                "Persisted for internal review only - not a final legal invoice or payment request."
        );
    }

    public ChargebackInvoiceDraftListResponse invoiceDrafts(
            AuthenticatedUser actor,
            String status,
            int limit
    ) {
        requireAdmin(actor, "Chargeback invoice draft access requires ADMIN.");
        String normalizedStatus = normalizeInvoiceStatusFilter(status);
        List<ChargebackInvoiceDraftRecord> records = normalizedStatus.isBlank()
                ? invoiceDraftRepository.findAll(limit)
                : invoiceDraftRepository.findByStatus(normalizedStatus, limit);
        return new ChargebackInvoiceDraftListResponse(
                records.size(),
                records.stream().map(ChargebackPreviewService::invoiceResponse).toList(),
                OffsetDateTime.now()
        );
    }

    public ChargebackInvoiceDraftApprovalResponse approveInvoiceDraft(
            AuthenticatedUser actor,
            long invoiceId,
            String approvalNote
    ) {
        requireAdmin(actor, "Chargeback invoice draft approval requires ADMIN.");
        ChargebackInvoiceDraftRecord current = invoiceDraftRepository.findById(invoiceId)
                .orElseThrow(() -> new ApiException(ApiErrorCode.NOT_FOUND, "Chargeback invoice draft not found."));
        if (!"DRAFT_REVIEW".equals(current.status())) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "Only DRAFT_REVIEW invoice drafts can be approved.");
        }
        ChargebackInvoiceDraftRecord approved = invoiceDraftRepository.updateApproval(
                invoiceId,
                "APPROVED_INTERNAL",
                actor.loginId(),
                normalizeApprovalNote(approvalNote)
        );
        return new ChargebackInvoiceDraftApprovalResponse(
                "APPROVED_INTERNAL",
                false,
                false,
                invoiceResponse(approved),
                OffsetDateTime.now(),
                "Approved internally for chargeback review only - not a final legal invoice or payment request."
        );
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

    public ChargebackAlertNotificationPreviewResponse alertNotificationPreview(
            AuthenticatedUser actor,
            ChargebackPreviewRequest request,
            String notificationChannel,
            String notificationTarget
    ) {
        ChargebackAlertResponse alerts = alerts(actor, request);
        String channel = normalizeNotificationChannel(notificationChannel);
        String target = normalizeNotificationTarget(notificationTarget);
        List<ChargebackAlertNotificationOrganizationResponse> notifications = alerts.organizations().stream()
                .map(alert -> notificationFor(alert, alerts.currency(), channel, target))
                .toList();
        return new ChargebackAlertNotificationPreviewResponse(
                "PREVIEW",
                channel,
                target,
                false,
                alerts.currency(),
                notifications.size(),
                notifications,
                OffsetDateTime.now(),
                "Preview only - no external notification was sent."
        );
    }

    public ChargebackAlertNotificationDispatchResponse queueAlertNotifications(
            AuthenticatedUser actor,
            ChargebackPreviewRequest request,
            String notificationChannel,
            String notificationTarget,
            String reason
    ) {
        ChargebackAlertNotificationPreviewResponse preview = alertNotificationPreview(
                actor,
                request,
                notificationChannel,
                notificationTarget
        );
        OffsetDateTime now = OffsetDateTime.now();
        String normalizedReason = normalizeReason(reason);
        List<ChargebackAlertNotificationDeliveryRecord> records = preview.notifications().stream()
                .map(notification -> new ChargebackAlertNotificationDeliveryRecord(
                        null,
                        notification.organizationId(),
                        notification.organizationName(),
                        notification.severity(),
                        money(notification.estimatedTotalCost()),
                        money(notification.warningAmount()),
                        money(notification.criticalAmount()),
                        preview.channel(),
                        preview.target(),
                        "PENDING_DELIVERY_ADAPTER",
                        0,
                        now,
                        notification.subject(),
                        notification.message(),
                        payloadJson(notification.payload()),
                        actor.loginId(),
                        normalizedReason,
                        now,
                        now,
                        null
                ))
                .toList();
        List<ChargebackAlertNotificationDeliveryRecord> saved = notificationDeliveryRepository.saveAll(records);
        return new ChargebackAlertNotificationDispatchResponse(
                "OUTBOX",
                "PENDING_DELIVERY_ADAPTER",
                false,
                saved.size(),
                saved.stream().map(ChargebackPreviewService::deliveryResponse).toList(),
                OffsetDateTime.now(),
                "Recorded in delivery outbox; no external notification was sent because delivery adapters are not configured."
        );
    }

    public ChargebackAlertNotificationOutboxResponse notificationOutbox(AuthenticatedUser actor, int limit) {
        if (actor == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
        }
        List<ChargebackAlertNotificationDeliveryRecord> records;
        if (actor.isAdmin()) {
            records = notificationDeliveryRepository.findAll(limit);
        } else if (actor.isOrgAdmin() && actor.organizationId() != null) {
            records = notificationDeliveryRepository.findByOrganizationId(actor.organizationId(), limit);
        } else {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, "Chargeback notification outbox access denied.");
        }
        return new ChargebackAlertNotificationOutboxResponse(
                records.size(),
                records.stream().map(ChargebackPreviewService::deliveryResponse).toList(),
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

    private static void requireAdmin(AuthenticatedUser actor, String message) {
        if (actor == null) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Authentication required.");
        }
        if (!actor.isAdmin()) {
            throw new ApiException(ApiErrorCode.AUTHORIZATION_FAILED, message);
        }
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

    private static String draftInvoiceNumber(
            ChargebackPreviewResponse preview,
            ChargebackOrganizationPreviewResponse organization
    ) {
        String date = preview.generatedAt().toLocalDate().format(DateTimeFormatter.BASIC_ISO_DATE);
        return "OSMU-DRAFT-" + date + "-" + organization.organizationId();
    }

    private static String normalizeNotificationChannel(String value) {
        String channel = value == null || value.isBlank()
                ? "WEBHOOK"
                : value.trim().toUpperCase(Locale.ROOT).replace(' ', '_');
        if (!channel.matches("[A-Z0-9_-]{1,32}")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "notificationChannel must be 1-32 alphanumeric, dash, or underscore characters.");
        }
        return channel;
    }

    private static String normalizeNotificationTarget(String value) {
        if (value == null || value.isBlank()) {
            return "UNCONFIGURED";
        }
        String target = value.trim();
        if (target.length() > 512 || target.contains("\r") || target.contains("\n")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "notificationTarget must be a single-line value up to 512 characters.");
        }
        return target;
    }

    private static String normalizeReason(String value) {
        if (value == null || value.isBlank()) {
            return "Chargeback alert notification queued from admin billing panel.";
        }
        String reason = value.trim();
        if (reason.length() > 512 || reason.contains("\r") || reason.contains("\n")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "reason must be a single-line value up to 512 characters.");
        }
        return reason;
    }

    private static String normalizeApprovalNote(String value) {
        if (value == null || value.isBlank()) {
            return "Internal chargeback invoice draft approved.";
        }
        String note = value.trim();
        if (note.length() > 512 || note.contains("\r") || note.contains("\n")) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "approvalNote must be a single-line value up to 512 characters.");
        }
        return note;
    }

    private static String normalizeInvoiceStatusFilter(String value) {
        if (value == null || value.isBlank()) {
            return "";
        }
        String status = value.trim().toUpperCase(Locale.ROOT);
        if (!List.of("DRAFT_REVIEW", "APPROVED_INTERNAL").contains(status)) {
            throw new ApiException(ApiErrorCode.VALIDATION_ERROR, "status must be DRAFT_REVIEW or APPROVED_INTERNAL.");
        }
        return status;
    }

    private static ChargebackInvoiceDraftRecord invoiceDraftRecord(
            ChargebackPreviewResponse preview,
            ChargebackOrganizationPreviewResponse organization,
            String requestedBy,
            String reason,
            OffsetDateTime now
    ) {
        BigDecimal trafficCost = money(organization.ingressCost()
                .add(organization.egressCost())
                .add(organization.internalCost()));
        return new ChargebackInvoiceDraftRecord(
                null,
                draftInvoiceNumber(preview, organization),
                "DRAFT_REVIEW",
                organization.organizationId(),
                organization.organizationName(),
                preview.currency(),
                preview.from(),
                preview.to(),
                preview.generatedAt(),
                preview.eventScanLimit(),
                money(preview.rates().storageGbMonthRate()),
                money(preview.rates().ingressGbRate()),
                money(preview.rates().egressGbRate()),
                money(preview.rates().internalGbRate()),
                money(preview.rates().operationThousandRate()),
                organization.bucketCount(),
                organization.objectCount(),
                organization.usedBytes(),
                money(organization.projectedStorageCost()),
                trafficCost,
                money(organization.operationCost()),
                money(organization.estimatedTotalCost()),
                requestedBy,
                null,
                reason,
                null,
                now,
                now,
                null,
                "Internal review only - not a final legal invoice or payment request."
        );
    }

    private static ChargebackInvoiceDraftResponse invoiceResponse(ChargebackInvoiceDraftRecord record) {
        return new ChargebackInvoiceDraftResponse(
                record.id() == null ? 0L : record.id(),
                record.invoiceNumber(),
                record.status(),
                false,
                false,
                record.organizationId(),
                record.organizationName(),
                record.currency(),
                record.from(),
                record.to(),
                record.previewGeneratedAt(),
                record.eventScanLimit(),
                money(record.storageGbMonthRate()),
                money(record.ingressGbRate()),
                money(record.egressGbRate()),
                money(record.internalGbRate()),
                money(record.operationThousandRate()),
                record.bucketCount(),
                record.objectCount(),
                record.usedBytes(),
                money(record.storageCost()),
                money(record.trafficCost()),
                money(record.operationCost()),
                money(record.estimatedTotalCost()),
                record.requestedBy(),
                record.approvedBy(),
                record.reason(),
                record.approvalNote(),
                record.createdAt(),
                record.updatedAt(),
                record.approvedAt(),
                record.note()
        );
    }

    private static ChargebackAlertNotificationDeliveryResponse deliveryResponse(
            ChargebackAlertNotificationDeliveryRecord record
    ) {
        return new ChargebackAlertNotificationDeliveryResponse(
                record.id() == null ? 0L : record.id(),
                record.organizationId(),
                record.organizationName(),
                record.severity(),
                money(record.estimatedTotalCost()),
                money(record.warningAmount()),
                money(record.criticalAmount()),
                record.channel(),
                record.target(),
                record.status(),
                record.attemptCount(),
                record.nextAttemptAt(),
                record.subject(),
                record.message(),
                record.payloadJson(),
                record.requestedBy(),
                record.reason(),
                record.createdAt(),
                record.updatedAt(),
                record.lastError()
        );
    }

    private static String payloadJson(Map<String, Object> payload) {
        StringBuilder json = new StringBuilder("{");
        int index = 0;
        for (Map.Entry<String, Object> entry : payload.entrySet()) {
            if (index > 0) {
                json.append(',');
            }
            json.append(jsonString(entry.getKey())).append(':').append(jsonValue(entry.getValue()));
            index += 1;
        }
        return json.append('}').toString();
    }

    private static String jsonValue(Object value) {
        if (value instanceof Number || value instanceof Boolean) {
            return String.valueOf(value);
        }
        return jsonString(value == null ? "" : String.valueOf(value));
    }

    private static String jsonString(String value) {
        return "\"" + value
                .replace("\\", "\\\\")
                .replace("\"", "\\\"")
                .replace("\r", "\\r")
                .replace("\n", "\\n")
                + "\"";
    }

    private static ChargebackAlertNotificationOrganizationResponse notificationFor(
            ChargebackAlertOrganizationResponse alert,
            String currency,
            String channel,
            String target
    ) {
        String subject = "[OSMU] " + alert.severity() + " chargeback alert for " + alert.organizationName();
        String message = alert.organizationName()
                + " projected chargeback cost is "
                + currency
                + " "
                + money(alert.estimatedTotalCost())
                + " (warning "
                + money(alert.warningAmount())
                + ", critical "
                + money(alert.criticalAmount())
                + ").";
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("eventType", "chargeback.threshold");
        payload.put("channel", channel);
        payload.put("target", target);
        payload.put("organizationId", alert.organizationId());
        payload.put("organizationName", alert.organizationName());
        payload.put("severity", alert.severity());
        payload.put("currency", currency);
        payload.put("estimatedTotalCost", money(alert.estimatedTotalCost()));
        payload.put("warningAmount", money(alert.warningAmount()));
        payload.put("criticalAmount", money(alert.criticalAmount()));
        return new ChargebackAlertNotificationOrganizationResponse(
                alert.organizationId(),
                alert.organizationName(),
                alert.severity(),
                money(alert.estimatedTotalCost()),
                money(alert.warningAmount()),
                money(alert.criticalAmount()),
                subject,
                message,
                payload
        );
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
