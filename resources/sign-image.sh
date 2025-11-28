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

# Sign the image
sign_image() {
  fulcio_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=fulcio -o jsonpath='{.items[0].spec.host}')
  rekor_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=rekor-server -o jsonpath='{.items[0].spec.host}')
  tuf_url=$(oc get route -n trusted-artifact-signer -l app.kubernetes.io/component=tuf -o jsonpath='{.items[0].spec.host}')
  keycloak_url=$(oc get route -n keycloak-system -l app=keycloak -o jsonpath='{.items[0].spec.host}')

  rhtas_user="rhtas-user"
  rhtas_user_pass="$(oc get secret -n keycloak-system keycloak-users -o jsonpath='{.data.rhtas-user-password}' | base64 -d)"

  curl -sSfk "https://${tuf_url}/root.json" -o "${workdir}/tuf-root.json"

  cosign initialize \
    --mirror="https://${tuf_url}" \
    --root="https://${tuf_url}/root.json" \
    --root-checksum="$(sha256sum "${workdir}/tuf-root.json" | cut -d' ' -f1)"

  TOKEN="$(python3 /usr/local/bin/get-keycloak-token.py \
    "https://${keycloak_url}" \
    "ztvp" \
    "trusted-artifact-signer" \
    "${rhtas_user}" \
    "${rhtas_user_pass}")"

  export COSIGN_FULCIO_URL="https://${fulcio_url}"
  export COSIGN_REKOR_URL="https://${rekor_url}"

  cosign sign "${1}" \
    --identity-token "${TOKEN}" \
    --yes
}

# Import Openshift Ingress CA certificate
import_ingress_ca() {
  oc get secret router-ca -n openshift-ingress-operator -o jsonpath='{.data.tls\.crt}' | base64 -d > "${workdir}/openshift-ingress-ca.crt"
  cp "${workdir}/openshift-ingress-ca.crt" /etc/pki/ca-trust/source/anchors/
  update-ca-trust
}

import_ingress_ca
sign_image "${1}"