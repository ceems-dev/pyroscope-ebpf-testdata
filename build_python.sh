#!/usr/bin/env bash

set -euf -o pipefail

size=5; check=0; install=0; archs="amd64 arm64";
while getopts 'hcip:a:' opt
do
  case "$opt" in
    c)
      check=1
      ;;
    i)
      install=1
      ;;
    p)
      size=$OPTARG
      ;;
    a)
      archs=$OPTARG
      ;;
    *)
      echo "Usage: $0 [-c] [-i] [-p] [-a]"
      echo "  -c: check versions"
      echo "  -i: install and configure asdf"
      echo "  -p: number of parallel builds"
      echo "  -a: architectures [options: amd64, arm64]"
      exit 1
      ;;
  esac
done

# Sanitary checks
if [ ${size} -le 0 ]
then
  echo "Number of parallel builds -p should be more than or equal to 1. Current value is ${size}"
  exit 1
fi

if [ -z "${archs}" ]
then
  echo "-a should not be empty. Accepted values are amd64, arm64 or both"
  exit 1
fi

# Check if archs are valid
VALID_ARCHS=("amd64" "arm64")
for arch in $archs; do
  if ! printf '%s\0' "${VALID_ARCHS[@]}" | grep -Fqxz -- "${arch}"; then
    echo "Not a valid arch value. Accepted values are amd64, arm64 or both"
    exit 1
  fi
done

function build_image() {
    local version=$1
    local arch=$2

    version_minor=$(echo ${version} | cut -d. -f1-2)

    if [ "${arch}" == "amd64" ]
    then
      output_dir="python-x64/${version}/"
    else
      output_dir="python-arm64/${version}/"
    fi

    docker build \
        --platform=linux/${arch} \
        --build-arg=PYTHON_VERSION_PATCH=${version} \
        --build-arg=PYTHON_VERSION_MINOR=${version_minor}  \
        -f dockerfiles/python.Dockerfile \
        --output=${output_dir} \
        dockerfiles
}

# Install and configure asdf
if [ ${install} -ne 0 ]
then
  wget -O /tmp/asdf.tar.gz https://github.com/asdf-vm/asdf/releases/download/v0.19.0/asdf-v0.19.0-linux-amd64.tar.gz >/dev/null 2>&1
  tar -xvf /tmp/asdf.tar.gz >/dev/null 2>&1

  # Ensure $HOME/.local/bin exists and move asdf there
  mkdir -p $HOME/.local/bin
  mv asdf $HOME/.local/bin

  # Add python plugin
  asdf plugin add python https://github.com/danhper/asdf-python.git >/dev/null 2>&1
  echo "asdf installed at $HOME/.local/bin and configured"
fi

# Make sure $HOME/.local/bin is on PATH
PATH="$HOME/.local/bin:$PATH"

# Check if asdf is available
if ! command -v asdf >/dev/null 2>&1
then
    echo "asdf could not be found. Use $0 -i to install and configure asdf"
    exit 1
fi

# Get all versions of Python
PYTHON_ALL_VERSIONS=$(asdf list all python | grep "^3\." | grep -v dev \
  | grep -v "^3\.[0-5]\." | grep -v "t" | grep -v "a" | grep -v "b" | grep -v "rc")

# Initialise missing versions
MISSING_VERSIONS_AMD64=()
MISSING_VERSIONS_ARM64=()

# Check missing versions
for version in $PYTHON_ALL_VERSIONS; do
  stat "python-x64/$version" >/dev/null 2>&1 || MISSING_VERSIONS_AMD64=("${MISSING_VERSIONS_AMD64[@]}" "$version")
  stat "python-arm64/$version" >/dev/null 2>&1 || MISSING_VERSIONS_ARM64=("${MISSING_VERSIONS_ARM64[@]}" "$version")
done

# If only dry run, print missing versions and exit
if [ ${check} -ne 0 ]
then
  echo "Missing version for amd64: ${MISSING_VERSIONS_AMD64[@]}"
  echo "Missing version for arm64: ${MISSING_VERSIONS_ARM64[@]}"
  exit 0
fi

if [ ${#MISSING_VERSIONS_AMD64[@]} -eq 0 ] && [ ${#MISSING_VERSIONS_ARM64[@]} -eq 0 ]; then
    echo "No missing version for amd64 and arm64 archs. Exiting..."
    exit 0
fi

# Make platforms
PLATFORMS=()
for arch in $archs; do
  PLATFORMS=("${PLATFORMS[@]}" "linux/${arch}")
done
PLATFORMS=$(printf "%s," "${PLATFORMS[@]}")

# Make base image
docker buildx build \
		--platform=${PLATFORMS} \
		-f dockerfiles/python.base.Dockerfile \
		-t python-base:latest \
		dockerfiles

# Build Python libs for AMD64
if [[ $archs =~ "amd64" ]]; then
    index=0
    while [[ $index -lt ${#MISSING_VERSIONS_AMD64[@]} ]]; do
        for version in "${MISSING_VERSIONS_AMD64[@]:$index:$size}"; do
          echo "Building library for version ${version} and arch amd64"
          build_image "${version}" "amd64" &
        done

        # Wait for all processes to finish before moving on to next chunk
        wait

        index=$((index + size))
    done
fi

# Build Python libs foor ARM64
if [[ $archs =~ "arm64" ]]; then
    index=0
    while [[ $index -lt ${#MISSING_VERSIONS_ARM64[@]} ]]; do
        for version in "${MISSING_VERSIONS_ARM64[@]:$index:$size}"; do
          echo "Building library for version ${version} and arch arm64"
          build_image "${version}" "arm64" &
        done

        # Wait for all processes to finish before moving on to next chunk
        wait

        index=$((index + size))
    done
fi
