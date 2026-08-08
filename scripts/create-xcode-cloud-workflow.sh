#!/usr/bin/env bash
#
# Drive Xcode Cloud from the CLI via the App Store Connect API. See ADR-004.
#
# Mints an ES256 JWT from your ASC API key (.p8) and hits the ci* endpoints so an Xcode
# Cloud *workflow* is defined from a file in this repo rather than clicked into a form.
#
# WHAT THIS CANNOT DO — one-time and interactive by design:
#   1. Mint the ASC API key: App Store Connect > Users and Access > Integrations.
#   2. Install the "Xcode Cloud" GitHub App on the repo (OAuth consent + app install).
#   3. Onboard the product itself. `ciProducts` does NOT allow CREATE — creating the
#      Xcode Cloud product and connecting the SCM provider is GUI-only
#      (Xcode > Integrate > Create Workflow). This script cannot bootstrap Xcode Cloud;
#      it configures a product that already exists.
#
# Auth env (all required):
#   ASC_KEY_ID     — the key's Key ID
#   ASC_ISSUER_ID  — the Issuer ID (same Integrations page)
#   ASC_KEY_PATH   — path to the downloaded AuthKey_XXXXXXXXXX.p8
#
# Usage:
#   create-xcode-cloud-workflow.sh products
#       list Xcode Cloud products (find Kiln's product id)
#   create-xcode-cloud-workflow.sh repositories <productId>
#       list SCM repositories on a product (find the repository id)
#   create-xcode-cloud-workflow.sh versions
#       list available macOS + Xcode version ids
#   create-xcode-cloud-workflow.sh workflows <productId>
#       list existing workflows — use after `create` to confirm what landed
#   create-xcode-cloud-workflow.sh create <workflow.json>
#       POST a ciWorkflows create request (start from ci-workflow.example.json)
#
# Deps: python3 + cryptography (JWT signing), jq, curl.
#
set -euo pipefail

: "${ASC_KEY_ID:?set ASC_KEY_ID}"
: "${ASC_ISSUER_ID:?set ASC_ISSUER_ID}"
: "${ASC_KEY_PATH:?set ASC_KEY_PATH (path to AuthKey_*.p8)}"
API="https://api.appstoreconnect.apple.com/v1"

# Mint a short-lived ES256 JWT for the App Store Connect API. PyJWT isn't required; the
# token is built by hand with `cryptography` (P-256 key, DER->JOSE signature conversion).
jwt() {
  python3 - "$ASC_KEY_ID" "$ASC_ISSUER_ID" "$ASC_KEY_PATH" <<'PY'
import base64, json, sys, time
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.serialization import load_pem_private_key
from cryptography.hazmat.primitives.asymmetric import ec, utils

kid, iss, path = sys.argv[1], sys.argv[2], sys.argv[3]
b64u = lambda b: base64.urlsafe_b64encode(b).rstrip(b"=")
with open(path, "rb") as f:
    key = load_pem_private_key(f.read(), password=None)
now = int(time.time())
seg = lambda o: b64u(json.dumps(o, separators=(",", ":")).encode())
signing_input = seg({"alg": "ES256", "kid": kid, "typ": "JWT"}) + b"." + \
    seg({"iss": iss, "iat": now, "exp": now + 1200, "aud": "appstoreconnect-v1"})
der = key.sign(signing_input, ec.ECDSA(hashes.SHA256()))
r, s = utils.decode_dss_signature(der)
sig = b64u(r.to_bytes(32, "big") + s.to_bytes(32, "big"))
sys.stdout.write((signing_input + b"." + sig).decode())
PY
}

# asc METHOD PATH [json-body-file]
asc() {
  local method="$1" path="$2" body="${3:-}" token
  token="$(jwt)"
  if [ -n "$body" ]; then
    # Strip the _README key: it documents the payload for humans and is not a valid
    # ciWorkflows attribute. Leaving it in is a 409.
    jq 'del(._README)' "$body" | curl -sS -X "$method" "$API$path" \
      -H "Authorization: Bearer $token" \
      -H "Content-Type: application/json" \
      --data-binary @-
  else
    curl -sS -X "$method" "$API$path" -H "Authorization: Bearer $token"
  fi
}

cmd="${1:-help}"
case "$cmd" in
  products)
    asc GET "/ciProducts?limit=200" \
      | jq -r '.data[] | "\(.id)\t\(.attributes.name)\t\(.attributes.productType)"'
    ;;
  repositories)
    pid="${2:?usage: repositories <productId>}"
    asc GET "/ciProducts/$pid/primaryRepositories?limit=200" \
      | jq -r '.data[] | "\(.id)\t\(.attributes.repositoryName)\t\(.attributes.httpCloneUrl)"'
    ;;
  versions)
    echo "# macOS versions (ciMacOsVersions)"
    asc GET "/ciMacOsVersions?limit=200" | jq -r '.data[] | "\(.id)\t\(.attributes.name)"'
    echo "# Xcode versions (ciXcodeVersions)"
    asc GET "/ciXcodeVersions?limit=200" | jq -r '.data[] | "\(.id)\t\(.attributes.name)"'
    ;;
  workflows)
    pid="${2:?usage: workflows <productId>}"
    asc GET "/ciProducts/$pid/workflows?limit=200" \
      | jq -r '.data[] | "\(.id)\t\(.attributes.name)\tenabled=\(.attributes.isEnabled)\tactions=\(.attributes.actions | length)"'
    ;;
  create)
    file="${2:?usage: create <workflow.json>}"
    asc POST "/ciWorkflows" "$file" | jq '.'
    ;;
  help|*)
    sed -n '2,33p' "$0"
    ;;
esac
