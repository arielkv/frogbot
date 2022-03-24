#!/bin/bash
set -eu

#function build(pkg, goos, goarch, exeName)
build () {
  pkg="$1"
  export GOOS="$2"
  export GOARCH="$3"
  exeName="$4"
  echo "Building $exeName for $GOOS-$GOARCH ..."

  CGO_ENABLED=0 jf go build -o "$exeName" -ldflags '-w -extldflags "-static" -X main.frogbotVersion='$version main.go
  chmod +x $exeName

  # Run verification after building plugin for the correct platform of this image.
  if [[ "$pkg" = "linux-386" ]]; then
    verifyVersionMatching
  fi
}

#function buildAndUpload(pkg, goos, goarch, fileExtension)
buildAndUpload () {
  pkg="$1"
  goos="$2"
  goarch="$3"
  fileExtension="$4"
  exeName="frogbot$fileExtension"

  build $pkg $goos $goarch $exeName

  destPath="$pkgPath/$version/$pkg/$exeName"
  echo "Uploading $exeName to $destPath ..."
  jf rt u "./$exeName" "$destPath"
}

# Verify version provided in pipelines UI matches version in frogbot source code.
verifyVersionMatching () {
  echo "Verifying provided version matches built version..."
  res=$(eval "./frogbot -v")
  exitCode=$?
  if [[ $exitCode -ne 0 ]]; then
    echo "Error: Failed verifying version matches"
    exit $exitCode
  fi

  # Get the version which is after the last space. (expected output to -v for example: "Frogbot version version v1.0.0")
  echo "Output: $res"
  builtVersion="${res##* }"
  # Compare versions
  if [[ "$builtVersion" != "$version" ]]; then
    echo "Versions dont match. Provided: $version, Actual: $builtVersion"
    exit 1
  fi
  echo "Versions match."
}

version="$1"
pkgPath="ecosys-frogbot/v1"

# Build and upload for every architecture.
# Keep 'linux-386' first to prevent unnecessary uploads in case the built version doesn't match the provided one.
buildAndUpload 'linux-386' 'linux' '386' ''
buildAndUpload 'linux-amd64' 'linux' 'amd64' ''
buildAndUpload 'linux-s390x' 'linux' 's390x' ''
buildAndUpload 'linux-arm64' 'linux' 'arm64' ''
buildAndUpload 'linux-arm' 'linux' 'arm' ''
buildAndUpload 'linux-ppc64' 'linux' 'ppc64' ''
buildAndUpload 'linux-ppc64le' 'linux' 'ppc64le' ''
buildAndUpload 'mac-386' 'darwin' 'amd64' ''
buildAndUpload 'windows-amd64' 'windows' 'amd64' '.exe'

jf rt u "./buildscripts/getFrogbot.sh" "$pkgPath/$version/"