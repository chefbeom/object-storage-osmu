package com.example.osmu.storagelayout;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class StorageLayoutCatalogTest {

    @Test
    void estimatesUsableCapacityByLayoutIntent() {
        long rawCapacityBytes = 4L * 1024L * 1024L * 1024L;

        assertThat(StorageLayoutCatalog.estimatedUsableCapacityBytes(StorageLayoutCode.JBOD, 4, rawCapacityBytes))
                .isEqualTo(rawCapacityBytes);
        assertThat(StorageLayoutCatalog.estimatedUsableCapacityBytes(StorageLayoutCode.RAID1, 4, rawCapacityBytes))
                .isEqualTo(2L * 1024L * 1024L * 1024L);
        assertThat(StorageLayoutCatalog.estimatedUsableCapacityBytes(StorageLayoutCode.RAID5, 4, rawCapacityBytes))
                .isEqualTo(3L * 1024L * 1024L * 1024L);
        assertThat(StorageLayoutCatalog.estimatedUsableCapacityBytes(StorageLayoutCode.RAID6, 4, rawCapacityBytes))
                .isEqualTo(2L * 1024L * 1024L * 1024L);
    }
}
