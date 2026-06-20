package com.example.osmu.billing;

import java.net.URI;
import java.util.Locale;

final class WebhookEndpointPolicy {

    private WebhookEndpointPolicy() {
    }

    static URI configuredUri(String value, boolean allowPrivateNetwork) {
        if (value == null || value.isBlank()) {
            return null;
        }
        try {
            URI uri = URI.create(value.trim());
            String scheme = uri.getScheme() == null ? "" : uri.getScheme().toLowerCase(Locale.ROOT);
            String host = uri.getHost();
            if (!("http".equals(scheme) || "https".equals(scheme))
                    || host == null
                    || host.isBlank()
                    || uri.getUserInfo() != null
                    || uri.getFragment() != null
                    || (!allowPrivateNetwork && isPrivateOrLocalHost(host))) {
                return null;
            }
            return uri;
        } catch (IllegalArgumentException exception) {
            return null;
        }
    }

    static boolean isPrivateOrLocalHost(String host) {
        String normalized = host == null ? "" : host.trim().toLowerCase(Locale.ROOT);
        while (normalized.endsWith(".")) {
            normalized = normalized.substring(0, normalized.length() - 1);
        }
        if (normalized.isBlank()
                || "localhost".equals(normalized)
                || normalized.endsWith(".localhost")
                || "localdomain".equals(normalized)
                || normalized.endsWith(".localdomain")
                || normalized.endsWith(".local")) {
            return true;
        }
        return isPrivateIpv4(normalized) || isPrivateIpv6(normalized);
    }

    private static boolean isPrivateIpv4(String host) {
        String[] parts = host.split("\\.", -1);
        if (parts.length != 4) {
            return false;
        }
        int[] values = new int[4];
        for (int index = 0; index < parts.length; index += 1) {
            if (parts[index].isBlank() || parts[index].length() > 3) {
                return false;
            }
            try {
                values[index] = Integer.parseInt(parts[index]);
            } catch (NumberFormatException exception) {
                return false;
            }
            if (values[index] < 0 || values[index] > 255) {
                return false;
            }
        }
        int first = values[0];
        int second = values[1];
        return first == 0
                || first == 10
                || first == 127
                || first >= 224
                || (first == 100 && second >= 64 && second <= 127)
                || (first == 169 && second == 254)
                || (first == 172 && second >= 16 && second <= 31)
                || (first == 192 && second == 168)
                || (first == 198 && (second == 18 || second == 19));
    }

    private static boolean isPrivateIpv6(String host) {
        String normalized = host;
        int zoneIndex = normalized.indexOf('%');
        if (zoneIndex >= 0) {
            normalized = normalized.substring(0, zoneIndex);
        }
        if (!normalized.contains(":")) {
            return false;
        }
        if (normalized.startsWith("::ffff:") && isPrivateIpv4(normalized.substring("::ffff:".length()))) {
            return true;
        }
        return "::".equals(normalized)
                || "::1".equals(normalized)
                || "0:0:0:0:0:0:0:0".equals(normalized)
                || "0:0:0:0:0:0:0:1".equals(normalized)
                || normalized.startsWith("fc")
                || normalized.startsWith("fd")
                || normalized.startsWith("fe8")
                || normalized.startsWith("fe9")
                || normalized.startsWith("fea")
                || normalized.startsWith("feb");
    }
}
