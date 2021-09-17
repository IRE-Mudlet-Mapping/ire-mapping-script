#!/bin/bash

if [ "$GITHUB_REPOSITORY" != "IRE-Mudlet-Mapping/ire-mapping-script" ]; then
  echo "Not on main repo, aborting"
  exit 0
fi

TEMPDIR="${HOME}/tmp/"

mkdir -p "${TEMPDIR}"

wget -O "${TEMPDIR}/mudlet-mapper.xml" http://ire-mudlet-mapping.github.io/ire-mapping-script/downloads/mudlet-mapper.xml

currentScriptSha1=$(grep -v "local newversion = " "${TEMPDIR}/mudlet-mapper.xml" | sha1sum | cut -d " " -f1)
newScriptSha1=$(grep -v "local newversion = " mudlet-mapper.xml | sha1sum | cut -d " " -f1)

if [ "${currentScriptSha1}" = "${newScriptSha1}" ]; then
  echo "No change in the script, aborting"
  exit 0
fi

mainDirectory=$(pwd)

cd ..
git clone --quiet --branch=gh-pages "https://${GH_TOKEN}@github.com/IRE-Mudlet-Mapping/ire-mapping-script.git" gh-pages

cd gh-pages/downloads || exit 1
cp "$mainDirectory/mudlet-mapper.xml" .

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

git config user.email "keneanung+ire-mapping@googlemail.com"
git config user.name "ire-mudlet-mapping-machine-account"

git commit -m"Release new version" .

git push --quiet
