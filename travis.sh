#!/bin/bash

if [ "$TRAVIS_BRANCH" != "master" -o "$TRAVIS_PULL_REQUEST" != "false" ]; then
  echo "Not on master, aborting"
  exit 0
fi

if [ "$TRAVIS_REPO_SLUG" != "IRE-Mudlet-Mapping/ire-mapping-script" ]; then
  echo "Not on main repo, aborting"
  exit 0
fi

wget -O "/usr/tmp/mudlet-mapper.xml" http://ire-mudlet-mapping.github.io/ire-mapping-script/downloads/mudlet-mapper.xml

currentScriptSha1=$(grep -v "local newversion = " /usr/tmp/mudlet-mapper.xml | sha1sum | cut -d " " -f1)
newScriptSha1=$(grep -v "local newversion = " mudlet-mapper.xml | sha1sum | cut -d " " -f1)

if [ "${currentScriptSha1}" = "${newScriptSha1}" ]; then
  echo "No change in the script, aborting"
  exit 0
fi

mainDirectory=`pwd`

cd ..
git clone --quiet --branch=gh-pages "https://ire-mudlet-mapping-machine-account:${GH_TOKEN}@github.com/IRE-Mudlet-Mapping/ire-mapping-script.git" gh-pages 

cd gh-pages/downloads
cp "$mainDirectory/mudlet-mapper.xml" .

datePart=$(date +"%y.%-m")
lastDatePart=$(echo "$(cat version 3> /dev/null)" | grep -o "^[0-9]*\.[0-9]*")
if [ "$lastDatePart" = "$datePart" ]; then
  versionPart=$(($(cat version | grep -o "[0-9]*$") + 1))
else
  versionPart=1
fi
version="$datePart.$versionPart"
sed -rbe 's/local newversion = &quot;developer&quot;/local newversion = \&quot;'$version'\&quot;/g' mudlet-mapper.xml > mudlet-mapper.xml.tmp && mv mudlet-mapper.xml.tmp mudlet-mapper.xml
echo "$version" > version

git config user.email "keneanung+ire-mapping@googlemail.com"
git config user.name "ire-mudlet-mapping-machine-account"

git commit -m"Release new version" .

git push --quiet
