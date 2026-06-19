package com.example.osmu.billing;

import static org.hamcrest.Matchers.hasItem;
import static org.hamcrest.Matchers.not;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.jayway.jsonpath.JsonPath;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.test.web.servlet.MockMvc;

@SpringBootTest
@AutoConfigureMockMvc
class AdminBillingControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void adminCanPreviewChargebackFromOrganizationUsageAndDataFlow() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int organizationId = createOrganization(adminToken, "Billing Org 1");
        createOrganizationBucket(adminToken, organizationId, "billing-org-bucket-1");

        MockMultipartFile file = new MockMultipartFile(
                "file",
                "billing.txt",
                MediaType.TEXT_PLAIN_VALUE,
                "billing-data".getBytes()
        );
        mockMvc.perform(multipart("/api/buckets/{bucketName}/objects", "billing-org-bucket-1")
                        .file(file)
                        .header("Authorization", "Bearer " + adminToken)
                        .param("key", "billing.txt"))
                .andExpect(status().isOk());

        mockMvc.perform(get("/api/admin/billing/chargeback-preview")
                        .header("Authorization", "Bearer " + adminToken)
                        .param("storageGbMonthRate", "1073741824")
                        .param("ingressGbRate", "1073741824")
                        .param("operationThousandRate", "1000")
                        .param("currency", "krw"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.currency").value("KRW"))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].usedBytes", hasItem(12)))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].ingressBytes", hasItem(12)))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].billableOperationCount", hasItem(1)))
                .andExpect(jsonPath("$.data.organizations[?(@.organizationName == 'Billing Org 1')].estimatedTotalCost", hasItem(25.0)));
    }

    @Test
    void orgAdminSeesOnlyOwnChargebackPreview() throws Exception {
        String adminToken = loginAndReturnAccessToken("admin", "password");
        int visibleOrg = createOrganization(adminToken, "Billing Visible Org 1");
        createOrganization(adminToken, "Billing Hidden Org 1");
        createUser(adminToken, "billing-org-admin-1", "billing-org-admin-1@example.com", "ORG_ADMIN", visibleOrg);
        String orgAdminToken = loginAndReturnAccessToken("billing-org-admin-1", "user-password");

        mockMvc.perform(get("/api/admin/billing/chargeback-preview")
                        .header("Authorization", "Bearer " + orgAdminToken))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.data.organizations[*].organizationName", hasItem("Billing Visible Org 1")))
                .andExpect(jsonPath("$.data.organizations[*].organizationName", not(hasItem("Billing Hidden Org 1"))));
    }

    private String loginAndReturnAccessToken(String loginId, String password) throws Exception {
        String response = mockMvc.perform(post("/api/auth/login")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "password": "%s"
                                }
                                """.formatted(loginId, password)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(response, "$.data.accessToken");
    }

    private int createOrganization(String adminToken, String name) throws Exception {
        String response = mockMvc.perform(post("/api/admin/organizations")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "description": "billing test",
                                  "defaultQuotaBytes": 2048
                                }
                                """.formatted(name)))
                .andExpect(status().isOk())
                .andReturn()
                .getResponse()
                .getContentAsString();

        return JsonPath.read(response, "$.data.id");
    }

    private void createOrganizationBucket(String adminToken, int organizationId, String bucketName) throws Exception {
        mockMvc.perform(post("/api/buckets")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "name": "%s",
                                  "quotaBytes": 1024,
                                  "ownerType": "ORG",
                                  "ownerId": %d
                                }
                                """.formatted(bucketName, organizationId)))
                .andExpect(status().isOk());
    }

    private void createUser(String adminToken, String loginId, String email, String role, int organizationId) throws Exception {
        mockMvc.perform(post("/api/admin/users")
                        .header("Authorization", "Bearer " + adminToken)
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "loginId": "%s",
                                  "email": "%s",
                                  "name": "%s",
                                  "password": "user-password",
                                  "role": "%s",
                                  "organizationId": %d
                                }
                                """.formatted(loginId, email, loginId, role, organizationId)))
                .andExpect(status().isOk());
    }
}
