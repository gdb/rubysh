#!/bin/sh

for i in {1..10}; do
    echo "[$i] Hello from stdout"
    echo >&2 "[$i] Hello from stderr"
    sleep 1
done
