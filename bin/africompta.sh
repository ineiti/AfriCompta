#!/usr/bin/env bash
cd $( dirname ${BASH_SOURCE[0]} )
echo "DATA_DIR=$HOME/Library/AfriCompta" > ../afri_compta.conf
echo $PATH
ruby --version
which ruby
./afri_compta.rb &
#AFRICOMPTA=$!
sleep 5
open -a Safari.app http://localhost:3302
#kill $!
#open -a Safari.app http://localhost:3302/$!
pkill -f "afri_compta.rb"
read a
