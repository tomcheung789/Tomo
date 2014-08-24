#!/bin/bash
FILES='tests/*.t'
TOMOC='build/tomoc'
echo "==> Building tests ..."
for f in $FILES
do
  $TOMOC $f
done