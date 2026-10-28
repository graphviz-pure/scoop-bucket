#!/usr/bin/env bash
# Downloads the latest graphviz-pure release's assets matching the given patterns into dist/,
# and refuses to continue unless every file has a valid build-provenance attestation from the
# graphviz-pure release workflow and matches the release's SHA256SUMS.
# Prints the release version (without the leading v).
set -euo pipefail
SRC=graphviz-pure/graphviz-pure
tag=$(gh release view --repo "$SRC" --json tagName --jq .tagName)
rm -rf dist && mkdir dist
gh release download "$tag" --repo "$SRC" --dir dist --pattern SHA256SUMS "${@/#/--pattern=}" >&2
for f in dist/*; do
  # Releases through 0.2.3 were attested for the tag; later ones are dispatched from master.
  gh attestation verify "$f" --repo "$SRC" \
    --signer-workflow "$SRC/.github/workflows/release.yml" --source-ref "refs/tags/$tag" >&2 ||
    gh attestation verify "$f" --repo "$SRC" \
      --signer-workflow "$SRC/.github/workflows/release.yml" --source-ref refs/heads/master >&2
done
(cd dist && sha256sum --check --ignore-missing SHA256SUMS >&2)
echo "${tag#v}"
