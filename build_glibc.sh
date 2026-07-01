
#!/usr/bin/env bash

set -euf -o pipefail

size=5; check=0;
while getopts 'hcp:' opt
do
  case "$opt" in
    c)
      check=1
      ;;
    p)
      size=$OPTARG
      ;;
    *)
      echo "Usage: $0 [-c] [-s]"
      echo "  -c: check versions"
      echo "  -p: number of parallel builds"
      exit 1
      ;;
  esac
done

function build_image() {
    local version=$1
    local arch=$2

    if [ "${arch}" == "amd64" ]
    then
      output_dir="glibc-x64/${version}/"
    else
      output_dir="glibc-arm64/${version}/"
    fi

    docker build \
        --platform=linux/${arch} \
        --build-arg=GLIBC_VERSION=${version} \
        -f dockerfiles/glibc.Dockerfile \
        --output=${output_dir} \
        dockerfiles
}

# Fetch all versions > 2.20
# https://ftp.gnu.org/gnu/glibc/
# https://mirror.ibcp.fr/pub/gnu/glibc/
GLIBC_ALL_VERSIONS=$(curl https://mirror.ibcp.fr/pub/gnu/glibc/ 2>/dev/null | python -c $'
import re
import sys
for i in sys.stdin:
  g=re.match(r\'.*href="(glibc-2\.(27|28|29|[3-9][\d]+)).tar.gz"\',i);
  if g is not None:
    print(g.group(1))
')

# Initialise missing versions
MISSING_VERSIONS_AMD64=()
MISSING_VERSIONS_ARM64=()

# Check missing versions
for version in $GLIBC_ALL_VERSIONS; do
  stat "glibc-x64/$version" >/dev/null 2>&1 || MISSING_VERSIONS_AMD64=("${MISSING_VERSIONS_AMD64[@]}" "$version")
  stat "glibc-arm64/$version" >/dev/null 2>&1 || MISSING_VERSIONS_ARM64=("${MISSING_VERSIONS_ARM64[@]}" "$version")
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

# Make base image
docker buildx build \
		--platform=linux/amd64,linux/arm64 \
		-f dockerfiles/glibc.base.Dockerfile \
		-t glibc-base:latest \
		dockerfiles

# Build Python libs for AMD64
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

# Build Python libs foor ARM64
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
