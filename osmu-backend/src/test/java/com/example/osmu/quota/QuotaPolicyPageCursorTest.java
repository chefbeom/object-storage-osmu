package com.example.osmu.quota;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class QuotaPolicyPageCursorTest {

    @Test
    void roundTripsCompositeQuotaPolicyCursor() {
        QuotaPolicyPageCursor cursor = new QuotaPolicyPageCursor("ORGANIZATION", 42L);

        assertThat(QuotaPolicyPageCursor.decode(cursor.encode())).isEqualTo(cursor);
    }

    @Test
    void rejectsMalformedCursor() {
        assertThatThrownBy(() -> QuotaPolicyPageCursor.decode("not-a-valid-cursor"))
                .isInstanceOf(IllegalArgumentException.class);
    }
}