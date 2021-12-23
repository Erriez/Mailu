.. _rpi_build:

Building for a Raspberry Pi
===========================

Mailu Docker images can be executed on the following ARM targets:

- Raspberry Pi 4 ARM64 64-bit (recommended board with >= 2GB memory)
- Raspberry Pi 3 ARMv7 32-bit (not fully tested)

A build can be started on a physical Pi, or via multi-architecture ``docker buildx bake`` on an AMD64 platform as described in next sections.

Build Mailu Docker images on the Pi
-----------------------------------

The following build script can be used to build images on the Pi:

.. code-block:: bash

  # Environment variables
  export DOCKER_ORG="yourname"
  export DOCKER_PREFIX="mailu-"
  export PINNED_MAILU_VERSION="local"

  # Build Mailu images
  cd tests/
  docker-compose -f build.yml build

  # Optional: Push to registry such as Ghcr or Dockerhub
  docker login <registry>
  docker-compose -f build.yml push

Build Mailu Docker images via docker buildx
-------------------------------------------

Install latest Docker according https://docs.docker.com/engine/install/ which includes ``buildx``.

The following build example can be used to build ARM images on a AMD64 platform:

.. code-block:: bash

  # Environment variables
  export DOCKER_ORG="yourname"
  export DOCKER_PREFIX="mailu-"
  export PINNED_MAILU_VERSION="local"

  # Run multiarch qemu container before running bake
  docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

  # Next commands should be executed in the tests/ directory
  cd tests/

  # Build Mailu images for all targets listed in build.hcl (default)
  docker buildx bake -f build.hcl --progress plain

  # Build a specific Mailu image such as docs, setup, front etc as listed in build.hcl
  docker buildx bake -f build.hcl --progress plain <IMAGE>

  # Build Mailu images for one or more targets
  docker buildx bake -f build.hcl --progress plain --set *.platform=linux/amd64,linux/arm64,linux/arm/v7

  # Build Mailu images for current running target and load into local Docker registry
  docker buildx bake -f build.hcl --progress plain --load

  # Optional: Push Mailu images to registry
  docker login <registry>
  docker buildx bake -f build.hcl --progress plain --push

Note: multi-architecture images can only build and executed on the current build architecture with the ``--load`` option.

Buildx configuration
--------------------

The ``tests/build.hcl`` file contains the following build configuration:

Images to build (Use comment character # to disable an image build)

.. code-block:: docker

  group "default" {
    targets = [
      "docs",
      "setup",

      "admin",
      "antispam",
      "front",
      "imap",
      "smtp",

      "rainloop",
      "roundcube",

      #"antivirus",
      #"fetchmail",
      #"resolver",
      #"traefik-certdumper",
      #"webdav"
    ]
  }

Default targets:

.. code-block:: docker

  target "defaults" {
    platforms = [ "linux/amd64", "linux/arm64", "linux/arm/v7" ]
    dockerfile="Dockerfile"
  }
