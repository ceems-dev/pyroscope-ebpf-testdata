#!/usr/bin/env bash

set -euf -o pipefail

size=5; check=0; archs="amd64 arm64";
while getopts 'hp:a:c' opt
do
  case "$opt" in
    p)
      size=$OPTARG
      ;;
    a)
      archs=$OPTARG
      ;;
    c)
      check=1
      ;;
    *)
      echo "Usage: $0 [-c] [-p] [-a]"
      echo "  -c: check versions"
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

# Get all versions of alpine Linux
ALPINE_ALL_VERSIONS=$(curl https://dl-cdn.alpinelinux.org/alpine/ 2>/dev/null | python -c $'
import re
import sys
for i in sys.stdin:
  g=re.match(r\'.*href="v(3\.8|3\.9|3\.[\d]{2}+)/"\',i);
  if g is not None:
    print(g.group(1))
')

# Initialise missing versions
MISSING_VERSIONS_AMD64=()
MISSING_VERSIONS_ARM64=()

# Get all missing versions
while IFS= read -r version; do
    stat "alpine-amd64/$version" >/dev/null 2>&1 || MISSING_VERSIONS_AMD64=("${MISSING_VERSIONS_AMD64[@]}" "$version")
    stat "alpine-arm64/$version" >/dev/null 2>&1 || MISSING_VERSIONS_ARM64=("${MISSING_VERSIONS_ARM64[@]}" "$version")
done <<< "${ALPINE_ALL_VERSIONS}"

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

# Build for AMD64
if [[ $archs =~ "amd64" ]]; then
    index=0
    while [[ $index -lt ${#MISSING_VERSIONS_AMD64[@]} ]]; do
        for version in "${MISSING_VERSIONS_AMD64[@]:$index:$size}"; do
          echo "Building musl for version ${version} and arch amd64"
          docker build --platform=linux/amd64 --build-arg="VERSION=${version}"  --output="alpine-amd64/${version}/"  -f dockerfiles/alpine-amd64.dockerfile dockerfiles &
        done

        # Wait for all processes to finish before moving on to next chunk
        wait

        index=$((index + size))
    done
fi

# Build for ARM64
if [[ $archs =~ "arm64" ]]; then
    index=0
    while [[ $index -lt ${#MISSING_VERSIONS_ARM64[@]} ]]; do
        for version in "${MISSING_VERSIONS_ARM64[@]:$index:$size}"; do
          echo "Building musl for version ${version} and arch arm64"
          docker build --platform=linux/arm64 --build-arg="VERSION=${version}"  --output="alpine-arm64/${version}/"  -f dockerfiles/alpine-arm64.dockerfile dockerfiles &
        done

        # Wait for all processes to finish before moving on to next chunk
        wait

        index=$((index + size))
    done
fi
