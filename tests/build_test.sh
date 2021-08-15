#!/bin/bash

# Default environment variables
DOCKER_ORG_DEFAULT=mailu-test
MAILU_VERSION_DEFAULT=master
VOLUME_DIR_DEFAULT=/tmp/mailu-volumes
VENV_DIR_DEFAULT=/tmp/mailu-venv

# Configure user or default environment variables
export DOCKER_ORG=${DOCKER_ORG:-$DOCKER_ORG_DEFAULT}
export MAILU_VERSION=${MAILU_VERSION:-$MAILU_VERSION_DEFAULT}
export VOLUME_DIR=${VOLUME_DIR:-$VOLUME_DIR_DEFAULT}
export VENV_DIR=${VENV_DIR:-$VENV_DIR_DEFAULT}


function usage()
{
    echo "Mailu build and test script"
    echo
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Note: Removing volume directory for each test requires sudo rights"
    echo
    echo "Default environment variables:"
    echo "  DOCKER_ORG=$DOCKER_ORG_DEFAULT"
    echo "  MAILU_VERSION=$MAILU_VERSION_DEFAULT"
    echo "  VOLUME_DIR=$VOLUME_DIR_DEFAULT"
    echo "  VENV_DIR=$VENV_DIR_DEFAULT"
    echo
    echo "OPTIONS:"
    echo "  -a, --all       Build and test images"
    echo "  -b, --build     Build images"
    echo "  -t, --test      Test images"
    echo "  -c, --clean     Remove caches and all images"
}

function check_environment()
{
    # Check environment
    if ! command -v docker &> /dev/null
    then
        echo "Docker not installed. Refer to https://docs.docker.com/engine/install/"
        exit 1
    fi

    if ! command -v docker-compose &> /dev/null
    then
        echo "Docker-compose not installed. Refer to https://docs.docker.com/compose/install/"
        exit 1
    fi

    if ! command -v python3 &> /dev/null
    then
        echo "python3 not installed. Run: sudo apt install python3"
        exit 1
    fi

    if ! command -v pip3 &> /dev/null
    then
        echo "pip3 not installed. Run: sudo apt install python3-pip"
        exit 1
    fi

    if ! command -v virtualenv &> /dev/null
    then
        echo "virtualenv not installed. Run: sudo apt install python3-virtualenv"
        exit 1
    fi

    # Print location and version executables
    echo "Installed versions:"
    docker -v
    docker-compose -v
    virtualenv --version
    pip3 --version
    echo

    # Removal volume directory requires sudo
    sudo rm -rf ${VOLUME_DIR}
}

function build_images()
{
    # Build all images
    docker-compose -f tests/build.yml build
}

function list_images()
{
    # List images
    docker images | grep ${DOCKER_ORG}/
}

function run_test()
{
    # Setup volume directory
    sudo rm -rf ${VOLUME_DIR}
    mkdir -p ${VOLUME_DIR}/mailu/
    cp -r tests/certs ${VOLUME_DIR}/mailu/
    chmod 600 ${VOLUME_DIR}/mailu/certs/*

    # Run test.py <name> <timemout minutes>
    python tests/compose/test.py $1 $2
    retVal=$?

    # Remove volume directory
    sudo rm -rf ${VOLUME_DIR} || true

    # Check exit code test
    if [ "${retVal}" -ne 0 ]; then
        echo "Test failed!"
        exit "${retVal}"
    fi
}

function run_build()
{
    echo "Building images"
    
    # Build images
    build_images

    # List created images
    list_images
}

function run_tests()
{
    echo "Testing images"

    # Create virtual environment for testing (keep cached as it does not change)
    if [ ! -d $VENV_DIR ]; then
        virtualenv $VENV_DIR
        source $VENV_DIR/bin/activate
        pip3 install -r tests/requirements.txt
    else
        source $VENV_DIR/bin/activate
    fi

    # Run tests
    run_test core 2
    run_test fetchmail 2
    run_test filters 3
    run_test rainloop 2
    run_test roundcube 2
    run_test webdav 2
}

function run_cleanup()
{
    echo "Running cleanup"

    # Remove build cache
    docker system prune -f

    # Remove previously created test containers and ignore errors
    docker-compose -f tests/compose/core/docker-compose.yml down || true
    docker-compose -f tests/compose/fetchmail/docker-compose.yml down || true
    docker-compose -f tests/compose/filters/docker-compose.yml down || true
    docker-compose -f tests/compose/rainloop/docker-compose.yml down || true
    docker-compose -f tests/compose/roundcube/docker-compose.yml down || true
    docker-compose -f tests/compose/webdav/docker-compose.yml down || true

    # Remove test images and ignore errors
    docker rmi ${DOCKER_ORG}/none:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/docs:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/setup:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/fetchmail:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/admin:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/nginx:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/dovecot:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/postfix:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/rspamd:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/clamav:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/radicale:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/postgresql:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/traefik-certdumper:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/unbound:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/rainloop:${MAILU_VERSION} || true
    docker rmi ${DOCKER_ORG}/roundcube:${MAILU_VERSION} || true

    # Remove virtualenv and volume directories
    rm -rf ${VENV_DIR} || true
    sudo rm -rf ${VOLUME_DIR} || true

    # List all images
    docker images
}

# ------------------------------------------------
# Main
# ------------------------------------------------
# Parse environment variables
RUN_BUILD=false
RUN_TESTS=false
RUN_CLEAN=false

POSITIONAL=()
while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
    -a|--all)
        RUN_BUILD=true
        RUN_TESTS=true
        shift # past argument
        ;;
    -b|--build)
        RUN_BUILD=true
        shift # past argument
        ;;
    -t|--test)
        RUN_TESTS=true
        shift # past argument
        ;;
    -c|--clean)
        RUN_CLEAN=true
        shift # past argument
        ;;
    *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
  esac
done

# Check what to do
if [ "${RUN_BUILD}" == false ] && [ "${RUN_TESTS}" == false ] && [ "${RUN_CLEAN}" == false ]; then
    usage
    exit 0
fi

# Save start time
TIME_START=$SECONDS

# Check environment
check_environment

# Clean
if $RUN_CLEAN; then
    run_cleanup
fi

# Build images
if $RUN_BUILD; then
    run_build
fi

# Run tests
if $RUN_TESTS; then
    run_tests
fi

# List test images
list_images

# Print total duration
ELAPSED_TIME=$(($SECONDS - $TIME_START))
echo "Total execution time: $(($ELAPSED_TIME/60)) min $(($ELAPSED_TIME%60)) sec"
