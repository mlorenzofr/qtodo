#!/bin/bash
#
# Authorization Code Flow Debug - For comparing with Quarkus logs
# This script shows EXACTLY what curl sends so you can compare with Quarkus
#

set -e

TENANT_ID="520cf09d-78ff-44ed-a731-abd623e73b09"
CLIENT_ID="1353eba6-51a5-4a5d-aae3-cc929611622b"
REDIRECT_URI="https://qtodo-qtodo.apps.ztvp.mlorenzo.edge-sro.rhecoeng.com/"
SPIFFE_JWT_SVID_PATH="/svids/jwt.token"

# Output file for debugging
DEBUG_FILE="/tmp/azure-auth-debug-$(date +%Y%m%d-%H%M%S).txt"

echo "=========================================="
echo "Azure Entra ID Authorization Code Flow"
echo "Debug Output for Quarkus Comparison"
echo "=========================================="
echo ""
echo "Debug output will be saved to: $DEBUG_FILE"
echo ""

# Start logging
{
    echo "=========================================="
    echo "DEBUG LOG - $(date)"
    echo "=========================================="
    echo ""

    # Generate state
    STATE=$(openssl rand -hex 16)
    ENCODED_REDIRECT_URI=$(printf %s "$REDIRECT_URI" | jq -sRr @uri)

    echo "1. CONFIGURATION"
    echo "================"
    echo "Tenant ID: $TENANT_ID"
    echo "Client ID: $CLIENT_ID"
    echo "Redirect URI (original): $REDIRECT_URI"
    echo "Redirect URI (encoded): $ENCODED_REDIRECT_URI"
    echo "State: $STATE"
    echo ""

    # Build authorization URL
    AUTH_URL="https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/authorize"
    AUTH_URL="${AUTH_URL}?client_id=${CLIENT_ID}"
    AUTH_URL="${AUTH_URL}&response_type=code"
    AUTH_URL="${AUTH_URL}&redirect_uri=${ENCODED_REDIRECT_URI}"
    AUTH_URL="${AUTH_URL}&scope=openid%20profile%20email%20offline_access"
    AUTH_URL="${AUTH_URL}&state=${STATE}"

    echo "2. AUTHORIZATION REQUEST"
    echo "========================"
    echo "Method: GET"
    echo "URL: $AUTH_URL"
    echo ""
    echo "Parameters:"
    echo "  client_id: ${CLIENT_ID}"
    echo "  response_type: code"
    echo "  redirect_uri: ${ENCODED_REDIRECT_URI}"
    echo "  scope: openid profile email offline_access"
    echo "  state: ${STATE}"
    echo ""
    echo "Note: NO PKCE parameters (code_challenge, code_challenge_method)"
    echo ""

} | tee "$DEBUG_FILE"

# Show authorization URL to user
echo "=========================================="
echo "Step 1: User Authorization"
echo "=========================================="
echo ""
echo "Open this URL in your browser:"
echo "$AUTH_URL"
echo ""

read -rp "Enter the authorization code: " AUTHORIZATION_CODE

if [ -z "$AUTHORIZATION_CODE" ]; then
    echo "Error: No authorization code provided"
    exit 1
fi

# Continue logging
{
    echo "3. AUTHORIZATION CODE RECEIVED"
    echo "==============================="
    echo "Code (first 50 chars): ${AUTHORIZATION_CODE:0:50}..."
    echo "Code length: ${#AUTHORIZATION_CODE} chars"
    echo "Code (last 20 chars): ...${AUTHORIZATION_CODE: -20}"
    echo ""

    # Get SPIFFE JWT-SVID
    echo "4. SPIFFE JWT-SVID"
    echo "=================="
    JWT_SVID=$(oc exec -n qtodo deploy/qtodo -c qtodo -- cat "$SPIFFE_JWT_SVID_PATH" | tr -d '\n\r')

    echo "JWT-SVID length: ${#JWT_SVID} chars"
    echo "JWT-SVID (first 50 chars): ${JWT_SVID:0:50}..."
    echo "JWT-SVID (last 20 chars): ...${JWT_SVID: -20}"
    echo ""

    # Decode JWT-SVID
    echo "JWT-SVID Header:"
    echo "$JWT_SVID" | cut -d. -f1 | base64 -d 2>/dev/null | jq . || echo "(Could not decode)"
    echo ""

    echo "JWT-SVID Claims:"
    echo "$JWT_SVID" | cut -d. -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode)"
    echo ""

    # Token request
    TOKEN_ENDPOINT="https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token"

    echo "5. TOKEN REQUEST (CURL)"
    echo "======================="
    echo "Method: POST"
    echo "URL: $TOKEN_ENDPOINT"
    echo "Content-Type: application/x-www-form-urlencoded"
    echo ""
    echo "Request Parameters:"
    echo "  grant_type: authorization_code"
    echo "  client_id: ${CLIENT_ID}"
    echo "  client_assertion_type: urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
    echo "  client_assertion: (JWT-SVID, ${#JWT_SVID} chars)"
    echo "  code: (authorization code, ${#AUTHORIZATION_CODE} chars)"
    echo "  redirect_uri: ${ENCODED_REDIRECT_URI}"
    echo ""
    echo "Note: NO code_verifier parameter (PKCE not used)"
    echo ""
    echo "=========================================="
    echo "EXACT CURL COMMAND:"
    echo "=========================================="
    echo ""
    echo "curl -v -X POST '${TOKEN_ENDPOINT}' \\"
    echo "  -H 'Content-Type: application/x-www-form-urlencoded' \\"
    echo "  -d 'grant_type=authorization_code' \\"
    echo "  -d 'client_id=${CLIENT_ID}' \\"
    echo "  -d 'client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer' \\"
    echo "  -d 'client_assertion=<JWT-SVID>' \\"
    echo "  -d 'code=<AUTHORIZATION-CODE>' \\"
    echo "  -d 'redirect_uri=${ENCODED_REDIRECT_URI}'"
    echo ""
    echo "=========================================="
    echo "COMPARE WITH QUARKUS:"
    echo "=========================================="
    echo ""
    echo "In Quarkus logs, look for:"
    echo "  - The token endpoint URL"
    echo "  - The grant_type value"
    echo "  - The client_id value"
    echo "  - The client_assertion_type value"
    echo "  - The redirect_uri value (should be: ${ENCODED_REDIRECT_URI})"
    echo "  - Whether code_verifier is present (should be: NO)"
    echo ""
    echo "Quarkus debug logging properties:"
    echo "  quarkus.log.category.\"io.quarkus.oidc\".level=DEBUG"
    echo "  quarkus.log.category.\"io.quarkus.oidc.runtime\".level=TRACE"
    echo ""

} | tee -a "$DEBUG_FILE"

echo ""
echo "Making token request with verbose output..."
echo ""

# Make request with verbose output
TOKEN_RESPONSE=$(curl -v -X POST "$TOKEN_ENDPOINT" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=authorization_code" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=${JWT_SVID}" \
    -d "code=${AUTHORIZATION_CODE}" \
    -d "redirect_uri=${ENCODED_REDIRECT_URI}" 2>&1)

# Continue logging
{
    echo "6. TOKEN RESPONSE"
    echo "================="
    echo ""

    # Extract just the JSON response
    RESPONSE_JSON=$(echo "$TOKEN_RESPONSE" | grep -v '^[<>*]' | grep -v '^{' | tail -n +$(echo "$TOKEN_RESPONSE" | grep -n '^{' | head -1 | cut -d: -f1))

    echo "HTTP Response:"
    echo "$TOKEN_RESPONSE" | grep -E '^< HTTP|^< [A-Z]' || echo "(Could not extract headers)"
    echo ""

    echo "Response Body:"
    echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p' | jq . 2>/dev/null || echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p'
    echo ""

    # Check for errors
    if echo "$TOKEN_RESPONSE" | grep -q '"error"'; then
        ERROR=$(echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p' | jq -r '.error' 2>/dev/null)
        ERROR_DESC=$(echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p' | jq -r '.error_description' 2>/dev/null)
        ERROR_CODES=$(echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p' | jq -r '.error_codes[]' 2>/dev/null)

        echo "=========================================="
        echo "ERROR DETECTED"
        echo "=========================================="
        echo "Error: $ERROR"
        echo "Description: $ERROR_DESC"
        echo "Error Codes: $ERROR_CODES"
        echo ""

        if [ "$ERROR" = "invalid_client" ]; then
            echo "AADSTS7000110 Analysis:"
            echo "======================="
            echo ""
            echo "Common causes:"
            echo "  1. client_id mismatch"
            echo "  2. client_assertion validation failed"
            echo "  3. Federated credential not configured correctly"
            echo "  4. SPIFFE JWT-SVID claims don't match federated credential"
            echo ""
            echo "Verify in Azure App Registration:"
            echo "  - Federated credential exists"
            echo "  - Issuer matches: $(echo "$JWT_SVID" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.iss')"
            echo "  - Subject matches: $(echo "$JWT_SVID" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.sub')"
            echo "  - Audience matches: $(echo "$JWT_SVID" | cut -d. -f2 | base64 -d 2>/dev/null | jq -r '.aud[]')"
            echo ""
        fi

        echo "Compare with Quarkus error:"
        echo "  - Is the error code the same?"
        echo "  - Is the error description the same?"
        echo "  - Are the request parameters identical?"
        echo ""
    else
        ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p' | jq -r '.access_token')
        ID_TOKEN=$(echo "$TOKEN_RESPONSE" | sed -n '/^{/,/^}/p' | jq -r '.id_token')

        echo "=========================================="
        echo "SUCCESS"
        echo "=========================================="
        echo "Access Token: ${ACCESS_TOKEN:0:50}..."
        echo "ID Token: ${ID_TOKEN:0:50}..."
        echo ""

        echo "ID Token Claims:"
        echo "$ID_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode)"
        echo ""

        echo "Access Token Claims:"
        echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode)"
        echo ""
    fi

    echo "=========================================="
    echo "FULL CURL VERBOSE OUTPUT"
    echo "=========================================="
    echo "$TOKEN_RESPONSE"
    echo ""

    echo "=========================================="
    echo "END OF DEBUG LOG"
    echo "=========================================="
    echo ""
    echo "To enable Quarkus debug logging, add to application.properties:"
    echo ""
    echo "quarkus.log.category.\"io.quarkus.oidc\".level=DEBUG"
    echo "quarkus.log.category.\"io.quarkus.oidc.runtime\".level=TRACE"
    echo "quarkus.log.category.\"io.quarkus.oidc.runtime.OidcProvider\".level=TRACE"
    echo "quarkus.log.category.\"io.vertx.core.http\".level=DEBUG"
    echo ""
    echo "Then compare:"
    echo "  1. The exact URL called (should be: $TOKEN_ENDPOINT)"
    echo "  2. The request parameters (grant_type, client_id, etc.)"
    echo "  3. The redirect_uri encoding (should be: $ENCODED_REDIRECT_URI)"
    echo "  4. Whether code_verifier is sent (should be: NO)"
    echo "  5. The client_assertion value (should be same JWT-SVID)"
    echo ""

} | tee -a "$DEBUG_FILE"

echo "=========================================="
echo "Debug information saved to:"
echo "$DEBUG_FILE"
echo "=========================================="
echo ""
echo "You can share this file with an AI to compare with Quarkus logs."
echo ""
