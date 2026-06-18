package com.example.osmu.object;

import java.util.zip.Checksum;

final class Crc64NvmeChecksum implements Checksum {

    static final int DIGEST_LENGTH_BYTES = 8;

    private static final long INITIAL_VALUE = 0xffffffffffffffffL;
    private static final long XOR_OUT = 0xffffffffffffffffL;
    private static final long REFLECTED_POLYNOMIAL = 0x9a6c9329ac4bc9b5L;

    private long value = INITIAL_VALUE;

    @Override
    public void update(int b) {
        value ^= b & 0xffL;
        for (int i = 0; i < 8; i++) {
            if ((value & 1L) == 1L) {
                value = (value >>> 1) ^ REFLECTED_POLYNOMIAL;
            } else {
                value >>>= 1;
            }
        }
    }

    @Override
    public void update(byte[] b, int off, int len) {
        if (b == null) {
            throw new NullPointerException("buffer");
        }
        if (off < 0 || len < 0 || off > b.length - len) {
            throw new ArrayIndexOutOfBoundsException();
        }
        for (int i = off; i < off + len; i++) {
            update(b[i]);
        }
    }

    @Override
    public long getValue() {
        return value ^ XOR_OUT;
    }

    @Override
    public void reset() {
        value = INITIAL_VALUE;
    }
}
