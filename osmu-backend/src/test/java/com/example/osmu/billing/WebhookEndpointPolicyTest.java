package com.example.osmu.billing;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class WebhookEndpointPolicyTest {

    @Test
    void rejectsPrivateNetworkWebhookUrlsByDefault() {
        assertThat(WebhookEndpointPolicy.configuredUri("http://localhost/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://127.0.0.1/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://10.0.0.1/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://172.16.0.1/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://192.168.1.1/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://[::1]/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://[::ffff:172.20.1.1]/hook", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("https://hooks.example.com/osmu", false)).isNotNull();
    }

    @Test
    void permitsPrivateNetworkWebhookUrlsOnlyWhenExplicitlyEnabled() {
        assertThat(WebhookEndpointPolicy.configuredUri("http://127.0.0.1/hook", true)).isNotNull();
        assertThat(WebhookEndpointPolicy.configuredUri("http://192.168.1.10/hook", true)).isNotNull();
    }

    @Test
    void rejectsUnsafeWebhookUrlShapes() {
        assertThat(WebhookEndpointPolicy.configuredUri("ftp://hooks.example.com/osmu", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("https://user:pass@hooks.example.com/osmu", false)).isNull();
        assertThat(WebhookEndpointPolicy.configuredUri("https://hooks.example.com/osmu#fragment", false)).isNull();
    }
}
