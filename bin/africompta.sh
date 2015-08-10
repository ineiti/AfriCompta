#!/usr/bin/env bash
cd $( dirname ${BASH_SOURCE[0]} )
echo "DATA_DIR=$HOME/Library/AfriCompta" > ../afri_compta.conf
#PATH="../../ruby/bin:$PATH"
echo $PATH
ruby --version
which ruby
pkill -f "afri_compta.rb"
./afri_compta.rb &
AFRICOMPTA=$!
sleep 5
echo $AFRICOMPTA
open -Wn -a Safari.app http://localhost:3302
#kill $!
#open -a Safari.app http://localhost:3302/$!
pkill -f "afri_compta.rb"
echo Done with AfriCompta
read a
