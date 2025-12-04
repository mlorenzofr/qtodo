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
  REKOR_URL="https://$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=rekor-server -o jsonpath='{.items[0].spec.host}')"
  TUF_URL="https://$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=tuf -o jsonpath='{.items[0].spec.host}')"
  OIDC_ISSUER_URL="https://$(oc get route -n keycloak-system -l app=keycloak -o jsonpath='{.items[0].spec.host}')/realms/ztvp"
  RHTAS_USER="rhtas-user"

  test -d /root/.sigstore || mkdir -p /root/.sigstore
  test -f /root/.sigstore/tuf-root.json || {
    curl -sSfk "${TUF_URL}/root.json" -o "/root/.sigstore/tuf-root.json"
    sha256sum "/root/.sigstore/tuf-root.json" | cut -d' ' -f1 > "/root/.sigstore/tuf-root.json.sha256"
  }

  cosign initialize \
    --root "/root/.sigstore/tuf-root.json" \
    --root-checksum "$(sha256sum "/root/.sigstore/tuf-root.json" | cut -d' ' -f1)" \
    --mirror "${TUF_URL}"

  cosign verify-blob "${1}" \
    --rekor-url="${REKOR_URL}" \
    --bundle "${1}.bundle" \
    --certificate-identity-regexp ".*${RHTAS_USER}.*" \
    --certificate-oidc-issuer-regexp "${OIDC_ISSUER_URL}"
}

# Import Openshift Ingress CA certificate
import_ingress_ca() {
  oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > "${workdir}/openshift-ingress-ca.crt"
  cp "${workdir}/openshift-ingress-ca.crt" /etc/pki/ca-trust/source/anchors/
  update-ca-trust
}

import_ingress_ca
verify_sbom_image "${1}"