package com.example.osmu.accesskey;

public final class AccessKeyPolicyNames {

    private AccessKeyPolicyNames() {
    }

    public static String policyName(long accessKeyId) {
        return "osmu-access-key-" + accessKeyId;
    }
}
