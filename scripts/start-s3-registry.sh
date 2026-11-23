#!/usr/bin/env bash
# Start a plain-HTTP registry:3.0 on a random loopback port, storing in S3.
# Reads REGISTRY_STORAGE_S3_* and REGISTRY_HTTP_SECRET from the environment and
# writes name=, port= and config= (a buildkitd.toml that trusts it) to $GITHUB_OUTPUT.
# Several runners can share a host, so neither the container name nor the port is fixed.
set -euo pipefail
: "${REGISTRY_STORAGE_S3_BUCKET:?s3-bucket is required}"
: "${REGISTRY_STORAGE_S3_ACCESSKEY:?aws-access-key-id is required}"
: "${REGISTRY_STORAGE_S3_SECRETKEY:?aws-secret-access-key is required}"
NAME="hs-s3-reg-${GITHUB_RUN_ID}-${GITHUB_RUN_ATTEMPT}-${GITHUB_JOB}-${1:-x}-$RANDOM"
docker run -d --name "$NAME" -p 127.0.0.1::5000 \
  -e REGISTRY_STORAGE=s3 -e REGISTRY_STORAGE_S3_BUCKET -e REGISTRY_STORAGE_S3_REGION \
  -e REGISTRY_STORAGE_S3_ACCESSKEY -e REGISTRY_STORAGE_S3_SECRETKEY -e REGISTRY_HTTP_SECRET \
  -e REGISTRY_HTTP_ADDR=:5000 registry:3.0 >/dev/null
PORT=$(docker port "$NAME" 5000/tcp | head -1 | sed 's/.*://')
for _ in $(seq 1 30); do curl -fs "http://127.0.0.1:$PORT/v2/" >/dev/null && break; sleep 1; done
if ! curl -fs "http://127.0.0.1:$PORT/v2/" >/dev/null; then
  docker logs "$NAME" 2>&1 | tail -20
  echo "::error::the S3-backed registry did not start"
  exit 1
fi
CONFIG="$RUNNER_TEMP/buildkitd-$NAME.toml"
printf '[registry."127.0.0.1:%s"]\n  http = true\n  insecure = true\n' "$PORT" > "$CONFIG"
# HUB_MIRROR may be set in a self-hosted runner's environment to a Docker Hub proxy.
if [ -n "${HUB_MIRROR:-}" ]; then
  MIRROR="${HUB_MIRROR#http://}"
  printf '[registry."docker.io"]\n  mirrors = ["%s"]\n[registry."%s"]\n  http = true\n  insecure = true\n' "$MIRROR" "$MIRROR" >> "$CONFIG"
fi
{ echo "name=$NAME"; echo "port=$PORT"; echo "config=$CONFIG"; } >> "$GITHUB_OUTPUT"
echo "S3-backed registry $NAME on 127.0.0.1:$PORT"
