#!/usr/bin/bash -e

# Change to your settings
export DOCKER_ORG="username"
export DOCKER_PREFIX="mailu-"
export PINNED_MAILU_VERSION="local"

# Run multiarch qemu container before running bake
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

# Build all images for all targets listed in build.hcl and push to registry
docker login
docker buildx bake -f build.hcl --progress plain --push $@
