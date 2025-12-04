#!/bin/sh

set -euo pipefail

test -n "${1}" || { echo "Usage: $0 <task>"; exit 1; }

case "$(uname)" in
  Darwin)
    os="darwin"
    os_arch="arm64"
    ;;
  Linux)
    os="linux"
    os_arch="amd64"
    ;;
  *)
    echo "Unsupported OS: $(uname)"
    exit 1
    ;;
esac

# Initialize cosign
initialize_cosign() {
  test -d /root/.sigstore || mkdir -p /root/.sigstore
  test -f /root/.sigstore/tuf-root.json || {
    curl -sSfk "${TUF_URL}/root.json" -o "/root/.sigstore/tuf-root.json"
    sha256sum "/root/.sigstore/tuf-root.json" | cut -d' ' -f1 > "/root/.sigstore/tuf-root.json.sha256"
  }

  cosign initialize \
    --root "/root/.sigstore/tuf-root.json" \
    --root-checksum "$(sha256sum "/root/.sigstore/tuf-root.json" | cut -d' ' -f1)" \
    --mirror "${TUF_URL}"
}

# Get the routes
get_routes() {
  export FULCIO_URL="https://$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=fulcio -o jsonpath='{.items[0].spec.host}')"
  export REKOR_URL="https://$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=rekor-server -o jsonpath='{.items[0].spec.host}')"
  export TUF_URL="https://$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=tuf -o jsonpath='{.items[0].spec.host}')"
  export OIDC_ISSUER_URL="https://$(oc get route -n keycloak-system -l app=keycloak -o jsonpath='{.items[0].spec.host}')/realms/ztvp"
}

# Get the Keycloak token
get_keycloak_token() {

  # Get the OIDC Issuer URL from Keycloak route
  export OIDC_TOKEN_URL="${OIDC_ISSUER_URL}/protocol/openid-connect/token"

  # Set user credentials
  export RHTAS_USER="rhtas-user"
  export RHTAS_USER_PASSWORD="$(oc get secret -n keycloak-system keycloak-users -o jsonpath='{.data.rhtas-user-password}' | base64 -d)"
  export RHTAS_CLIENT_ID="trusted-artifact-signer"

  # Request a new access token
  if [ "${1}" = "shell" ]; then
    curl -sk "${OIDC_TOKEN_URL}" \
    --header 'Accept: application/json' \
    --data-urlencode 'grant_type=password' \
    --data-urlencode "client_id=${RHTAS_CLIENT_ID}" \
    --data-urlencode "username=${RHTAS_USER}" \
    --data-urlencode "password=${RHTAS_USER_PASSWORD}" \
    --data-urlencode 'scope=openid email profile' \
    | jq -r .access_token
  elif [ "${1}" = "python" ]; then
    python3 /usr/local/bin/get-keycloak-token.py \
    "${OIDC_TOKEN_URL}" \
    "ztvp" \
    "${RHTAS_CLIENT_ID}" \
    "${RHTAS_USER}" \
    "${RHTAS_USER_PASSWORD}"
  fi
}

# Sign the artifact
sign_artifact() {
  bundle="${1}.bundle"

  initialize_cosign

  TOKEN="$(get_keycloak_token "shell")"

  cosign sign-blob "${1}" \
    --identity-token "${TOKEN}" \
    --fulcio-url "${FULCIO_URL}" \
    --rekor-url "${REKOR_URL}" \
    --bundle "${bundle}" \
    --yes
}

# Sign the image
sign_image() {

  initialize_cosign

  TOKEN="$(get_keycloak_token "shell")"

  cosign sign "${1}" \
    --identity-token "${TOKEN}" \
    --fulcio-url "${FULCIO_URL}" \
    --rekor-url "${REKOR_URL}" \
    --registry-username username \
    --registry-password username \
    --yes
}

# Verify the SBOM of the image
verify_image() {

  export RHTAS_USER="rhtas-user"

  initialize_cosign

  ec validate image \
    --image "${1}" \
    --certificate-identity-regexp ".*${RHTAS_USER}.*" \
    --certificate-oidc-issuer "${OIDC_ISSUER_URL}" \
    --rekor-url "${REKOR_URL}" \
    --show-successes
}

# Verify the SBOM of the image
verify_sbom() {

  export RHTAS_USER="rhtas-user"

  initialize_cosign

  cosign verify-blob "${1}" \
    --rekor-url="${REKOR_URL}" \
    --bundle "${1}.bundle" \
    --certificate-identity-regexp ".*${RHTAS_USER}.*" \
    --certificate-oidc-issuer-regexp "${OIDC_ISSUER_URL}"
}

# Import Openshift Ingress CA certificate
import_ingress_ca() {
  oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > "/tmp/openshift-ingress-ca.crt"
  cp "/tmp/openshift-ingress-ca.crt" /etc/pki/ca-trust/source/anchors/
  update-ca-trust
}

# Attest the SBOM of the image
attest_sbom_image() {

  initialize_cosign

  TOKEN="$(get_keycloak_token "shell")"

  cosign attest "${1}" \
    --fulcio-url "${FULCIO_URL}" \
    --rekor-url "${REKOR_URL}" \
    --identity-token "${TOKEN}" \
    --predicate "${2}" \
    --type spdxjson \
    --registry-username username \
    --registry-password username \
    --yes
}


# Main
import_ingress_ca
get_routes

case "${1}" in
  attest-sbom)
    attest_sbom_image "${2}" "${3}"
    ;;
  sign-artifact)
    sign_artifact "${2}"
    ;;
  sign-image)
    sign_image "${2}"
    ;;
  verify-image)
    verify_image "${2}"
    ;;
  verify-sbom)
    verify_sbom "${2}"
    ;;
  *)
    echo "Unknown task: ${1}"
    exit 1
    ;;
esac