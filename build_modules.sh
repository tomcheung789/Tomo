#!/bin/bash
FPC='fpc'
TOMOC='build/tomoc'
echo "==> Building modules ..."
$FPC src/modules/TomoType.tpas
$TOMOC src/modules/TomoSys.t
echo 
echo 
echo "==> Move to build ..."
mv src/modules/*.ppu build/modules/
mv src/modules/*.o build/modules/
