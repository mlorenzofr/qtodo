#!/bin/sh

set -euo pipefail

test -n "${1}" || { echo "Usage: $0 <artifact>"; exit 1; }
test -f "${1}" || { echo "Artifact not found: ${1}"; exit 1; }

workdir="$(mktemp -d)"

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

# Get the Keycloak token
get_keycloak_token() {

  # Get the OIDC Issuer URL from Keycloak route
  export OIDC_TOKEN_URL="https://$(oc get route -n keycloak-system -l app=keycloak -o jsonpath='{.items[0].spec.host}')/realms/ztvp/protocol/openid-connect/token"  

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
  fulcio_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=fulcio -o jsonpath='{.items[0].spec.host}')
  rekor_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=rekor-server -o jsonpath='{.items[0].spec.host}')
  tuf_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=tuf -o jsonpath='{.items[0].spec.host}')

  bundle="${1}.bundle"

  curl -sSfk "https://${tuf_url}/root.json" -o "${workdir}/tuf-root.json"

  cosign initialize \
    --mirror="https://${tuf_url}" \
    --root="https://${tuf_url}/root.json" \
    --root-checksum="$(sha256sum "${workdir}/tuf-root.json" | cut -d' ' -f1)"

  TOKEN="$(get_keycloak_token "shell")"

  export COSIGN_FULCIO_URL="https://${fulcio_url}"
  export COSIGN_REKOR_URL="https://${rekor_url}"

  cosign sign-blob "${1}" \
    --identity-token "${TOKEN}" \
    --bundle "${bundle}" \
    --yes
}

# Import Openshift Ingress CA certificate
import_ingress_ca() {
  oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > "${workdir}/openshift-ingress-ca.crt"
  cp "${workdir}/openshift-ingress-ca.crt" /etc/pki/ca-trust/source/anchors/
  update-ca-trust
}

import_ingress_ca
sign_artifact "${1}"