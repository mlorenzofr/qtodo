#!/bin/sh

set -euo pipefail

test -n "${1}" || { echo "Usage: $0 <image>"; exit 1; }

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

# Verify the SBOM of the image
verify_sbom_image() {
  # fulcio_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=fulcio -o jsonpath='{.items[0].spec.host}')
  rekor_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=rekor-server -o jsonpath='{.items[0].spec.host}')
  tuf_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=tuf -o jsonpath='{.items[0].spec.host}')
  keycloak_url=$(oc get route -n keycloak-system -l app=keycloak -o jsonpath='{.items[0].spec.host}')

  rhtas_user="rhtas-user"
  # rhtas_user_pass="$(oc get secret -n keycloak-system keycloak-users -o jsonpath='{.data.rhtas-user-password}' | base64 -d)"

  test -d /root/.sigstore || mkdir -p /root/.sigstore
  test -f /root/.sigstore/tuf-root.json || {
    curl -sSfk "https://${tuf_url}/root.json" -o "/root/.sigstore/tuf-root.json"
    sha256sum "/root/.sigstore/tuf-root.json" | cut -d' ' -f1 > "/root/.sigstore/tuf-root.json.sha256"
  }

  cosign initialize \
    --root "/root/.sigstore/tuf-root.json" \
    --root-checksum "$(sha256sum "/root/.sigstore/tuf-root.json" | cut -d' ' -f1)" \
    --mirror "https://${tuf_url}"

  ec validate image \
    --image "${1}" \
    --certificate-identity-regexp ".*${rhtas_user}.*" \
    --certificate-oidc-issuer "https://${keycloak_url}/realms/ztvp" \
    --rekor-url "https://${rekor_url}" \
    --show-successes
}

# Import Openshift Ingress CA certificate
import_ingress_ca() {
  oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > "${workdir}/openshift-ingress-ca.crt"
  cp "${workdir}/openshift-ingress-ca.crt" /etc/pki/ca-trust/source/anchors/
  update-ca-trust
}

import_ingress_ca
verify_sbom_image "${1}"