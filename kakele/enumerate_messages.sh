#!/usr/bin/bash

for PROTO in $(find proto -type f -name '*.proto'); do
    PACKAGE=$(sed -rn 's|^package (.*);$|\1|p' "$PROTO")
    for MSG in $(sed -rn 's|^message (.*)\{$|\1|p' "$PROTO"); do
        echo "${PACKAGE}.${MSG}" >> msgs
    done
done
