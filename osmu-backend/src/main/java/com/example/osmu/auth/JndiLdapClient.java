package com.example.osmu.auth;

import com.example.osmu.common.error.ApiErrorCode;
import com.example.osmu.common.error.ApiException;
import java.util.Hashtable;
import javax.naming.Context;
import javax.naming.NamingEnumeration;
import javax.naming.NamingException;
import javax.naming.directory.Attribute;
import javax.naming.directory.Attributes;
import javax.naming.directory.DirContext;
import javax.naming.directory.InitialDirContext;
import javax.naming.directory.SearchControls;
import javax.naming.directory.SearchResult;
import org.springframework.stereotype.Service;

@Service
public class JndiLdapClient implements LdapClient {

    @Override
    public LdapUserRecord searchUser(LdapSearchRequest request) {
        SearchControls controls = new SearchControls();
        controls.setSearchScope(SearchControls.SUBTREE_SCOPE);
        controls.setReturningAttributes(new String[] { request.emailAttribute(), request.displayNameAttribute() });
        DirContext context = null;
        try {
            context = openContext(
                request.url(),
                request.bindDn(),
                request.bindPassword(),
                request.connectTimeoutMs(),
                request.readTimeoutMs()
            );
            NamingEnumeration<SearchResult> results = context.search(
                    request.baseDn(),
                    request.userSearchFilter(),
                    new Object[] { request.loginId() },
                    controls
            );
            if (!results.hasMore()) {
                throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP user is not provisioned.");
            }
            SearchResult result = results.next();
            if (results.hasMore()) {
                throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP user search is ambiguous.");
            }
            String dn = result.getNameInNamespace();
            Attributes attributes = result.getAttributes();
            return new LdapUserRecord(
                    dn,
                    attributeValue(attributes, request.emailAttribute()),
                    attributeValue(attributes, request.displayNameAttribute())
            );
        } catch (ApiException exception) {
            throw exception;
        } catch (NamingException exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP user search failed.");
        } finally {
            close(context);
        }
    }

    @Override
    public void bind(LdapBindRequest request) {
        DirContext context = null;
        try {
            context = openContext(
                request.url(),
                request.userDn(),
                request.password(),
                request.connectTimeoutMs(),
                request.readTimeoutMs()
            );
            // Successful context creation proves the supplied LDAP credentials.
        } catch (NamingException exception) {
            throw new ApiException(ApiErrorCode.AUTHENTICATION_REQUIRED, "LDAP authentication failed.");
        } finally {
            close(context);
        }
    }

    private DirContext openContext(String url, String principal, String credential, int connectTimeoutMs, int readTimeoutMs)
            throws NamingException {
        Hashtable<String, String> environment = new Hashtable<>();
        environment.put(Context.INITIAL_CONTEXT_FACTORY, "com.sun.jndi.ldap.LdapCtxFactory");
        environment.put(Context.PROVIDER_URL, url);
        environment.put("com.sun.jndi.ldap.connect.timeout", String.valueOf(connectTimeoutMs));
        environment.put("com.sun.jndi.ldap.read.timeout", String.valueOf(readTimeoutMs));
        if (hasText(principal)) {
            environment.put(Context.SECURITY_AUTHENTICATION, "simple");
            environment.put(Context.SECURITY_PRINCIPAL, principal);
            environment.put(Context.SECURITY_CREDENTIALS, credential == null ? "" : credential);
        }
        return new InitialDirContext(environment);
    }

    private String attributeValue(Attributes attributes, String name) throws NamingException {
        if (attributes == null || !hasText(name)) {
            return "";
        }
        Attribute attribute = attributes.get(name);
        Object value = attribute == null ? null : attribute.get();
        return value instanceof String text ? text.trim() : "";
    }

    private boolean hasText(String value) {
        return value != null && !value.isBlank();
    }

    private void close(DirContext context) {
        if (context == null) {
            return;
        }
        try {
            context.close();
        } catch (NamingException ignored) {
            // Login result was already determined; close failure is not user-visible.
        }
    }
}
