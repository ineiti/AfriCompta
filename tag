#!/bin/bash
if [ ! "$1" ]; then
  echo Please give a tag-name
  exit
fi

hg tag "$1"
git tag "$1"
./commit "Added Tag $1"
