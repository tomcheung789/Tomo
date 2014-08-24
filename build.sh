#!/bin/bash
FPC='fpc'
PLEX='plex'
PYACC='pyacc'
echo "==> Building indent marker ..."
$PLEX src/indentmarker.l
$FPC src/indentmarker.pas -obuild/indentmarker -gl
echo 
echo 
echo "==> Building scanner ..."
$PLEX src/scanner.l
echo 
echo 
echo "==> Building parser ..."
$PYACC src/parser.y
echo 
echo 
echo "==> Building compiler ..."
$FPC src/parser.pas -obuild/tomoc -gl
