#!/bin/bash
#
# Test Azure Entra ID Authorization Code Flow with SPIFFE JWT-SVID Client Assertion
#
# This script simulates what Quarkus does with application-type=web-app
# NOTE: PKCE is NOT used because Azure Entra ID doesn't support PKCE with client assertions
#

set -e

# ========================================
# CONFIGURATION - Update these values
# ========================================

TENANT_ID="520cf09d-78ff-44ed-a731-abd623e73b09"
CLIENT_ID="1353eba6-51a5-4a5d-aae3-cc929611622b"
REDIRECT_URI="https://qtodo-qtodo.apps.ztvp.mlorenzo.edge-sro.rhecoeng.com/"  # Must be registered in Azure
SPIFFE_JWT_SVID_PATH="/svids/jwt.token"

# Scopes to request (space-separated, will be URL encoded)
SCOPES="openid profile email offline_access"

# ========================================
# STEP 1: Build Authorization URL
# ========================================

echo "=========================================="
echo "STEP 1: Authorization URL"
echo "=========================================="

# Generate random state for CSRF protection
STATE=$(openssl rand -hex 16)

# URL encode scopes and redirect URI
ENCODED_SCOPES=$(echo "$SCOPES" | sed 's/ /%20/g')
ENCODED_REDIRECT_URI=$(printf %s "$REDIRECT_URI" | jq -sRr @uri)

# Build authorization URL (NO PKCE - not supported with client assertions)
AUTH_URL="https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/authorize"
AUTH_URL="${AUTH_URL}?client_id=${CLIENT_ID}"
AUTH_URL="${AUTH_URL}&response_type=code"
AUTH_URL="${AUTH_URL}&redirect_uri=${ENCODED_REDIRECT_URI}"
AUTH_URL="${AUTH_URL}&scope=${ENCODED_SCOPES}"
AUTH_URL="${AUTH_URL}&state=${STATE}"

echo ""
echo "Authorization URL:"
echo "$AUTH_URL"
echo ""
echo "Note: PKCE is NOT used (Azure doesn't support PKCE with client assertions)"
echo ""
echo "=========================================="
echo "STEP 2: User Authentication"
echo "=========================================="
echo ""
echo "1. Open this URL in your browser:"
echo "   $AUTH_URL"
echo ""
echo "2. Log in with your Azure credentials"
echo ""
echo "3. After successful login, you'll be redirected to:"
echo "   ${REDIRECT_URI}?code=<AUTHORIZATION_CODE>&state=${STATE}"
echo ""
echo "4. Copy the 'code' parameter from the redirect URL"
echo ""
echo "Expected redirect format:"
echo "   ${REDIRECT_URI}?code=0.AXoA...&state=${STATE}"
echo ""

# Wait for user to paste the authorization code
read -rp "Enter the authorization code: " AUTHORIZATION_CODE

if [ -z "$AUTHORIZATION_CODE" ]; then
    echo "Error: No authorization code provided"
    exit 1
fi

echo ""
echo "Received authorization code: ${AUTHORIZATION_CODE:0:20}..."
echo ""

# ========================================
# STEP 3: Read SPIFFE JWT-SVID
# ========================================

echo "=========================================="
echo "STEP 3: Read SPIFFE JWT-SVID"
echo "=========================================="

JWT_SVID=$(oc exec -n qtodo deploy/qtodo -c qtodo -- cat "$SPIFFE_JWT_SVID_PATH" | tr -d '\n\r')
echo "SPIFFE JWT-SVID loaded successfully"
echo "JWT-SVID (first 50 chars): ${JWT_SVID:0:50}..."

# Decode and display JWT-SVID claims
echo ""
echo "JWT-SVID Claims:"
echo "$JWT_SVID" | cut -d. -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode JWT)"
echo ""

# ========================================
# STEP 4: Exchange Authorization Code for Tokens
# ========================================

echo "=========================================="
echo "STEP 4: Exchange Code for Tokens"
echo "=========================================="

TOKEN_ENDPOINT="https://login.microsoftonline.com/${TENANT_ID}/oauth2/v2.0/token"

echo ""
echo "Token endpoint: $TOKEN_ENDPOINT"
echo ""

# Using SPIFFE JWT-SVID as client_assertion (NO code_verifier - PKCE not used)
echo "Request with SPIFFE JWT-SVID client_assertion:"
echo ""

# Show the exact curl command for debugging
echo "=========================================="
echo "EXACT CURL COMMAND BEING EXECUTED:"
echo "=========================================="
echo ""
echo "curl -X POST '$TOKEN_ENDPOINT' \\"
echo "  -H 'Content-Type: application/x-www-form-urlencoded' \\"
echo "  -d 'grant_type=authorization_code' \\"
echo "  -d 'client_id=${CLIENT_ID}' \\"
echo "  -d 'client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer' \\"
echo "  -d 'client_assertion=${JWT_SVID:0:50}...' \\"
echo "  -d 'code=${AUTHORIZATION_CODE:0:30}...' \\"
echo "  -d 'redirect_uri=${ENCODED_REDIRECT_URI}'"
echo ""
echo "Full parameter details:"
echo "  grant_type: authorization_code"
echo "  client_id: ${CLIENT_ID}"
echo "  client_assertion_type: urn:ietf:params:oauth:client-assertion-type:jwt-bearer"
echo "  client_assertion length: ${#JWT_SVID} chars"
echo "  code length: ${#AUTHORIZATION_CODE} chars"
echo "  redirect_uri: ${ENCODED_REDIRECT_URI}"
echo ""
echo "Making request..."
echo ""

TOKEN_RESPONSE=$(curl -s -X POST "$TOKEN_ENDPOINT" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    -d "grant_type=authorization_code" \
    -d "client_id=${CLIENT_ID}" \
    -d "client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer" \
    -d "client_assertion=${JWT_SVID}" \
    -d "code=${AUTHORIZATION_CODE}" \
    -d "redirect_uri=${ENCODED_REDIRECT_URI}")

echo ""
echo "Response:"
echo "$TOKEN_RESPONSE" | jq . 2>/dev/null || echo "$TOKEN_RESPONSE"
echo ""

# Check for errors
if echo "$TOKEN_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    echo "=========================================="
    echo "ERROR: Token request failed"
    echo "=========================================="
    echo "Error: $(echo "$TOKEN_RESPONSE" | jq -r '.error')"
    echo "Description: $(echo "$TOKEN_RESPONSE" | jq -r '.error_description')"
    exit 1
fi

# ========================================
# STEP 5: Extract and Display Tokens
# ========================================

echo "=========================================="
echo "STEP 5: Token Details"
echo "=========================================="

ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.access_token')
ID_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.id_token')
REFRESH_TOKEN=$(echo "$TOKEN_RESPONSE" | jq -r '.refresh_token')

echo ""
echo "Access Token (first 50 chars): ${ACCESS_TOKEN:0:50}..."
echo "ID Token (first 50 chars): ${ID_TOKEN:0:50}..."
echo "Refresh Token: $([ "$REFRESH_TOKEN" != "null" ] && echo "Present" || echo "Not provided")"
echo ""

# Decode and display ID token claims
if [ "$ID_TOKEN" != "null" ]; then
    echo "ID Token Claims:"
    echo "$ID_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode)"
    echo ""
fi

# Decode and display access token claims
echo "Access Token Claims:"
echo "$ACCESS_TOKEN" | cut -d. -f2 | base64 -d 2>/dev/null | jq . || echo "(Could not decode)"
echo ""

# ========================================
# STEP 6: Test API Call
# ========================================

echo "=========================================="
echo "STEP 6: Test API Call with Access Token"
echo "=========================================="

echo ""
echo "You can now use this access token to call your API:"
echo ""
echo "curl -H \"Authorization: Bearer \$ACCESS_TOKEN\" \\"
echo "  https://qtodo-qtodo.apps.ztvp.mlorenzo.edge-sro.rhecoeng.com/api/todos"
echo ""

# Save tokens to file for later use
TOKENS_FILE="/tmp/azure-tokens-$(date +%s).json"
echo "$TOKEN_RESPONSE" > "$TOKENS_FILE"
echo "Tokens saved to: $TOKENS_FILE"
echo ""

echo "=========================================="
echo "COMPLETE!"
echo "=========================================="
