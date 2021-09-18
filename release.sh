#!/bin/bash

if [ "$GITHUB_REPOSITORY" != "IRE-Mudlet-Mapping/ire-mapping-script" ]; then
  echo "Not on main repo, aborting"
  exit 0
fi

currentScriptSha1=$(grep -v "local newversion = " "${GITHUB_WORKSPACE}/gh-pages/downloads/mudlet-mapper.xml" | sha1sum | cut -d " " -f1)
newScriptSha1=$(grep -v "local newversion = " "${GITHUB_WORKSPACE}/master/mudlet-mapper.xml" | sha1sum | cut -d " " -f1)

if [ "${currentScriptSha1}" = "${newScriptSha1}" ]; then
  echo "No change in the script, aborting"
  exit 0
fi

cd "${GITHUB_WORKSPACE}/gh-pages/downloads" || exit 1
cp "${GITHUB_WORKSPACE}/master/mudlet-mapper.xml" .

datePart=$(date +"%y.%-m")
lastDatePart=$(grep -o "^[0-9]*\.[0-9]*" version)
if [ "$lastDatePart" = "$datePart" ]; then
  versionPart=$(($(grep -o "[0-9]*$" version) + 1))
else
  versionPart=1
fi
version="$datePart.$versionPart"
sed -rbe "s/local newversion = \"developer\"/local newversion = \"$version\"/g" "mudlet-mapper.xml" > "mudlet-mapper.xml.tmp" && mv "mudlet-mapper.xml.tmp" "mudlet-mapper.xml"
echo "$version" > version

git commit -m"Release new version" .

git push --quiet
