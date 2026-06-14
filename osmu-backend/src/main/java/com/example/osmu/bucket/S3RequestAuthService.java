package com.example.osmu.bucket;

import com.example.osmu.accesskey.AccessKeyBucketList;
import com.example.osmu.accesskey.AccessKeyService;
import com.example.osmu.auth.AuthContext;
import com.example.osmu.auth.AuthenticatedUser;
import com.example.osmu.auth.JwtAuthInterceptor;
import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.stereotype.Service;

@Service
public class S3RequestAuthService {

    private static final String ACCESS_KEY_HEADER = "X-OSMU-Access-Key";
    private static final String SECRET_KEY_HEADER = "X-OSMU-Secret-Key";

    private final AuthContext authContext;
    private final AccessKeyService accessKeyService;
    private final BucketService bucketService;
    private final S3SignatureV4Verifier signatureV4Verifier;

    public S3RequestAuthService(
            AuthContext authContext,
            AccessKeyService accessKeyService,
            BucketService bucketService,
            S3SignatureV4Verifier signatureV4Verifier
    ) {
        this.authContext = authContext;
        this.accessKeyService = accessKeyService;
        this.bucketService = bucketService;
        this.signatureV4Verifier = signatureV4Verifier;
    }

    public AuthenticatedUser currentUser(HttpServletRequest request, String bucketName, String requiredPermission) {
        return currentUserAny(request, bucketName, requiredPermission);
    }

    public AuthenticatedUser currentUserAny(HttpServletRequest request, String bucketName, String... requiredPermissions) {
        if (request.getAttribute(JwtAuthInterceptor.CLAIMS_ATTRIBUTE) != null) {
            return authContext.currentUser(request);
        }
        if (signatureV4Verifier.isSignatureRequest(request) && isBlank(request.getHeader(SECRET_KEY_HEADER))) {
            String accessKey = signatureV4Verifier.accessKey(request);
            signatureV4Verifier.verify(request, accessKeyService.signingSecret(accessKey));
            return accessKeyService.authenticateSignedAny(accessKey, bucketName, requiredPermissions);
        }
        String accessKey = accessKey(request);
        String secretKey = request.getHeader(SECRET_KEY_HEADER);
        return accessKeyService.authenticateAny(accessKey, secretKey, bucketName, requiredPermissions);
    }

    public S3BucketListAccess bucketListAccess(HttpServletRequest request) {
        if (request.getAttribute(JwtAuthInterceptor.CLAIMS_ATTRIBUTE) != null) {
            AuthenticatedUser user = authContext.currentUser(request);
            return new S3BucketListAccess(user, bucketService.list(user));
        }
        if (signatureV4Verifier.isSignatureRequest(request) && isBlank(request.getHeader(SECRET_KEY_HEADER))) {
            String accessKey = signatureV4Verifier.accessKey(request);
            signatureV4Verifier.verify(request, accessKeyService.signingSecret(accessKey));
            AccessKeyBucketList bucketList = accessKeyService.authenticateSignedBucketList(accessKey);
            return new S3BucketListAccess(bucketList.user(), bucketList.buckets());
        }
        AccessKeyBucketList bucketList = accessKeyService.authenticateBucketList(accessKey(request), request.getHeader(SECRET_KEY_HEADER));
        return new S3BucketListAccess(bucketList.user(), bucketList.buckets());
    }

    private String accessKey(HttpServletRequest request) {
        String headerAccessKey = request.getHeader(ACCESS_KEY_HEADER);
        if (headerAccessKey != null && !headerAccessKey.isBlank()) {
            return headerAccessKey;
        }
        String authorization = request.getHeader("Authorization");
        if (authorization == null || authorization.isBlank()) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key authentication required.");
        }
        String prefix = "Credential=";
        int credentialStart = authorization.indexOf(prefix);
        if (credentialStart < 0) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "Access key authentication required.");
        }
        int valueStart = credentialStart + prefix.length();
        int valueEnd = authorization.indexOf(',', valueStart);
        String credential = authorization.substring(valueStart, valueEnd < 0 ? authorization.length() : valueEnd).trim();
        int scopeStart = credential.indexOf('/');
        return scopeStart < 0 ? credential : credential.substring(0, scopeStart);
    }

    private boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
