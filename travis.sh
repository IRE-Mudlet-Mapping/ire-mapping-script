#!/bin/bash

if [ "$TRAVIS_BRANCH" != "master" -o "$TRAVIS_PULL_REQUEST" != "false" ]; then
  echo "Not on master, aborting"
  exit 0
fi

if [ "$TRAVIS_REPO_SLUG" != "IRE-Mudlet-Mapping/ire-mapping-script" ]; then
  echo "Not on main repo, aborting"
  exit 0
fi

mainDirectory=`pwd`

cd ..
git clone --quiet --branch=gh-pages "https://IREMappingBot:${GH_TOKEN}@github.com/IRE-Mudlet-Mapping/ire-mapping-script.git" gh-pages 

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

git config user.email "IREMappingBot@travis-ci.org"
git config user.name "IREMappingBot"

git commit -m"Release new version" .

git push --quiet
