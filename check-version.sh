#!/usr/bin/env bash
set -euo pipefail

zon_version="$(awk -F'"' '/\.version = "/ { print $2; exit }' build.zig.zon)"
src_version="$(awk -F'"' '/pub const version = "/ { print $2; exit }' src/version.zig)"

if [[ -z "${zon_version}" ]]; then
  echo "Error: failed to parse .version from build.zig.zon"
  exit 1
fi

if [[ -z "${src_version}" ]]; then
  echo "Error: failed to parse version from src/version.zig"
  exit 1
fi

if [[ ! "${zon_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: build.zig.zon version is not semver: ${zon_version}"
  exit 1
fi

if [[ ! "${src_version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Error: src/version.zig version is not semver: ${src_version}"
  exit 1
fi

if [[ "${zon_version}" != "${src_version}" ]]; then
  echo "Error: version mismatch"
  echo "- build.zig.zon: ${zon_version}"
  echo "- src/version.zig: ${src_version}"
  exit 1
fi

echo "Version consistency check passed: ${zon_version}"
