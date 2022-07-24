#!/bin/bash
# Unbound
# A container running Unbound, a recursive and caching DNS resolver.
#
# Copyright (c) 2022  SGS Serious Gaming & Simulations GmbH
#
# This work is licensed under the terms of the MIT license.
# For a copy, see LICENSE file or <https://opensource.org/licenses/MIT>.
#
# SPDX-License-Identifier: MIT
# License-Filename: LICENSE

ROOT_HINTS="https://www.internic.net/domain/named.cache"

set -eu -o pipefail
export LC_ALL=C
shopt -u nullglob

[ -v CI_TOOLS ] && [ "$CI_TOOLS" == "SGSGermany" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS' not set or invalid" >&2; exit 1; }

[ -v CI_TOOLS_PATH ] && [ -d "$CI_TOOLS_PATH" ] \
    || { echo "Invalid build environment: Environment variable 'CI_TOOLS_PATH' not set or invalid" >&2; exit 1; }

source "$CI_TOOLS_PATH/helper/common.sh.inc"
source "$CI_TOOLS_PATH/helper/container.sh.inc"
source "$CI_TOOLS_PATH/helper/container-alpine.sh.inc"

BUILD_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
source "$BUILD_DIR/container.env"

readarray -t -d' ' TAGS < <(printf '%s' "$TAGS")

echo + "CONTAINER=\"\$(buildah from $(quote "$BASE_IMAGE"))\"" >&2
CONTAINER="$(buildah from "$BASE_IMAGE")"

echo + "MOUNT=\"\$(buildah mount $(quote "$CONTAINER"))\"" >&2
MOUNT="$(buildah mount "$CONTAINER")"

pkg_install "$CONTAINER" --virtual .fetch-deps \
    curl

pkg_install "$CONTAINER" --virtual .unbound \
    unbound

user_changeuid "$CONTAINER" unbound 65536

echo + "rsync -v -rl --exclude .gitignore ./src/ …/" >&2
rsync -v -rl --exclude '.gitignore' "$BUILD_DIR/src/" "$MOUNT/"

cmd buildah run "$CONTAINER" -- \
    chown unbound:unbound "/var/lib/unbound"

cmd buildah run "$CONTAINER" -- \
    curl -L -o "/etc/unbound/root.hints" \
        "$ROOT_HINTS"

pkg_remove "$CONTAINER" .fetch-deps

VERSION="$(pkg_version "$CONTAINER" unbound)"

cleanup "$CONTAINER"

cmd buildah config \
    --port "53/udp" \
    --port "53/tcp" \
    "$CONTAINER"

cmd buildah config \
    --cmd '[ "unbound" ]' \
    "$CONTAINER"

cmd buildah config \
    --annotation org.opencontainers.image.title="Unbound" \
    --annotation org.opencontainers.image.description="A container running Unbound, a recursive and caching DNS resolver." \
    --annotation org.opencontainers.image.version="$VERSION" \
    --annotation org.opencontainers.image.url="https://github.com/SGSGermany/unbound" \
    --annotation org.opencontainers.image.authors="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.vendor="SGS Serious Gaming & Simulations GmbH" \
    --annotation org.opencontainers.image.licenses="MIT" \
    --annotation org.opencontainers.image.base.name="$BASE_IMAGE" \
    --annotation org.opencontainers.image.base.digest="$(podman image inspect --format '{{.Digest}}' "$BASE_IMAGE")" \
    "$CONTAINER"

con_commit "$CONTAINER" "${TAGS[@]}"
