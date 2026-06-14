package com.example.osmu.accesskey;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Arrays;
import java.util.Base64;
import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

@Component
public class AccessKeySecretCipher {

    private static final String CIPHER = "AES/GCM/NoPadding";
    private static final int IV_BYTES = 12;
    private static final int TAG_BITS = 128;

    private final SecretKeySpec secretKey;
    private final SecureRandom random = new SecureRandom();

    public AccessKeySecretCipher(
            @Value("${osmu.access-key.secret-encryption-key:local-dev-access-key-secret-encryption-key-change-me}") String secretEncryptionKey
    ) {
        this.secretKey = new SecretKeySpec(sha256(secretEncryptionKey), "AES");
    }

    public String encrypt(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            byte[] iv = new byte[IV_BYTES];
            random.nextBytes(iv);
            Cipher cipher = Cipher.getInstance(CIPHER);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, new GCMParameterSpec(TAG_BITS, iv));
            byte[] encrypted = cipher.doFinal(value.getBytes(StandardCharsets.UTF_8));
            byte[] output = new byte[iv.length + encrypted.length];
            System.arraycopy(iv, 0, output, 0, iv.length);
            System.arraycopy(encrypted, 0, output, iv.length, encrypted.length);
            return Base64.getEncoder().encodeToString(output);
        } catch (GeneralSecurityException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "Access key secret encryption failed.");
        }
    }

    public String decrypt(String value) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            byte[] input = Base64.getDecoder().decode(value);
            if (input.length <= IV_BYTES) {
                throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key signing secret is invalid.");
            }
            byte[] iv = Arrays.copyOfRange(input, 0, IV_BYTES);
            byte[] encrypted = Arrays.copyOfRange(input, IV_BYTES, input.length);
            Cipher cipher = Cipher.getInstance(CIPHER);
            cipher.init(Cipher.DECRYPT_MODE, secretKey, new GCMParameterSpec(TAG_BITS, iv));
            return new String(cipher.doFinal(encrypted), StandardCharsets.UTF_8);
        } catch (IllegalArgumentException | GeneralSecurityException exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key signing secret is invalid.");
        }
    }

    private byte[] sha256(String value) {
        try {
            return MessageDigest.getInstance("SHA-256")
                    .digest((value == null ? "" : value).getBytes(StandardCharsets.UTF_8));
        } catch (GeneralSecurityException exception) {
            throw new ApiException(ApiErrorCode.INTERNAL_ERROR, "SHA-256 is unavailable.");
        }
    }
}
