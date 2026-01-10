#!/bin/bash
TAG=$(git describe --tags --abbrev=0)
OUTPUT="dist/ShakeIt-${TAG}.zip"

mkdir -p dist

if [ -f "$OUTPUT" ]; then
    read -p "$OUTPUT exists. Overwrite? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

git archive --format=zip --prefix=ShakeIt/ -o "$OUTPUT" HEAD Core.lua LICENSE README.md ShakeIt.toc
echo "Created $OUTPUT"
