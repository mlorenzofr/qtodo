package org.fictional.qtodo;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import jakarta.enterprise.context.ApplicationScoped;

import org.eclipse.microprofile.config.inject.ConfigProperty;
import org.jboss.logging.Logger;

import io.quarkus.arc.Unremovable;
import io.quarkus.oidc.common.OidcEndpoint;
import io.quarkus.oidc.common.OidcRequestFilter;

/**
 * Workaround for Quarkus OIDC not sending client_id alongside client_assertion
 * in the token exchange request body.
 *
 * Azure Entra ID with federated identity credentials (SPIFFE/SPIRE workload
 * identity) requires client_id to be present in the token request when
 * client_assertion is used. Without it, Azure cannot map the federated
 * credential to the correct app registration and returns AADSTS7000110
 * ("multiple application identifiers found").
 *
 * In Quarkus 3.20.x OidcProviderClientImpl, the jwt-bearer authentication
 * branch only adds client_assertion and client_assertion_type but skips
 * client_id. This filter appends it to the encoded form body.
 */
@ApplicationScoped
@Unremovable
@OidcEndpoint(OidcEndpoint.Type.TOKEN)
public class AzureClientIdRequestFilter implements OidcRequestFilter {

    private static final Logger LOG = Logger.getLogger(AzureClientIdRequestFilter.class);

    @ConfigProperty(name = "quarkus.oidc.client-id")
    String clientId;

    @Override
    public void filter(OidcRequestContext requestContext) {
        if (requestContext.requestBody() == null) {
            return;
        }
        String body = requestContext.requestBody().toString();
        if (body.contains("client_assertion=") && !body.contains("client_id=")) {
            String encoded = URLEncoder.encode(clientId, StandardCharsets.UTF_8);
            requestContext.requestBody().appendString("&client_id=" + encoded);
            LOG.info("Injected client_id into token request for Azure federated credential authentication");
        }
    }
}
