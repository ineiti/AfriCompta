#!/usr/bin/env bash
cd $( dirname ${BASH_SOURCE[0]} )
echo "DATA_DIR=$HOME/Library/AfriCompta" > ../afri_compta.conf
./afri_compta.rb
open -a Safari.app http://localhost:3302
read a
