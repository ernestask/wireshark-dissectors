#!/bin/bash

protoc -Iproto --descriptor_set_out=descriptor_set.pb proto/**/*.proto
./generate_prefs.py descriptor_set.pb
rm -f descriptor_set.pb
