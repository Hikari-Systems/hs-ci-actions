# hs-ci-actions

Composite GitHub Actions for multi-arch container builds whose layer cache follows the runner.

## `docker-build`

Builds one platform and pushes it **by digest** (no tag), then hands the digest to
`merge-manifest` through an artifact that expires after one day. The cache profile is chosen
per run:

| Profile | Where it fits | What it does |
|---|---|---|
| `s3reg` | self-hosted runners in the same cloud as the bucket | starts a `registry:3.0` container on a random loopback port, backed by S3, and uses `type=registry,mode=max` |
| `blacksmith` | Blacksmith runners | uses `useblacksmith/setup-docker-builder` (sticky-disk builder state); nothing is exported |
| `gha` | GitHub-hosted runners | `type=gha,mode=max` |
| `none` | anywhere | no layer cache |
| `auto` (default) | anywhere | `blacksmith` on Blacksmith, `gha` on GitHub-hosted, `s3reg` on other self-hosted runners |

A `blacksmith` request on a non-Blacksmith runner falls back to `auto`. An `s3reg` request
without a bucket and credentials falls back to `none`.

```yaml
- uses: hikari-systems/hs-ci-actions/docker-build@v1
  with:
    image: ghcr.io/owner/name
    platform: amd64            # or arm64
    cache: auto
    registry-token: ${{ secrets.GITHUB_TOKEN }}
    # s3reg only:
    s3-bucket: my-cache-bucket
    s3-region: ${{ secrets.AWS_REGION }}
    aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

Optional: `context`, `file`, `build-args`, `secret-envs`, `ssh`, `cache-scope`,
`artifact-prefix` (set it when a workflow builds more than one image).

## `merge-manifest`

Downloads the digests and runs `docker buildx imagetools create`. Only the final tags exist in
the registry; the platform images are children of the index, as with a single-step multi-arch push.

```yaml
- uses: hikari-systems/hs-ci-actions/merge-manifest@v1
  with:
    image: ghcr.io/owner/name
    registry-token: ${{ secrets.GITHUB_TOKEN }}
    # tags: one per line; default is the commit SHA, the branch name (/ → -) and latest
```

## Versioning

`v1` is a moving tag for the latest `v1.x.y`. Pin `@v1.x.y` if you need it fixed.
