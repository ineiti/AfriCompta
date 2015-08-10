#!/usr/bin/env bash
cd $( dirname ${BASH_SOURCE[0]} )
echo "DATA_DIR=$HOME/Library/AfriCompta" > ../afri_compta.conf
./afri_compta.rb
read a
