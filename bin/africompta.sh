#!/usr/bin/env bash
cd "$( dirname ${BASH_SOURCE[0]} )/.."
DIR_AC="$(pwd)"
DIR_RES="$DIR_AC/.."

echo "DATA_DIR=$HOME/Library/AfriCompta" > ../afri_compta.conf
export PATH="$DIR_RES/ruby/bin:$PATH"
export GEM_PATH="$DIR_RES/ruby/lib/ruby"
echo path: $PATH
echo gem_path: $GEM_PATH
ruby --version
which ruby
pkill -f "afri_compta.rb"
bin/afri_compta.rb &
AFRICOMPTA=$!
sleep 5
echo $AFRICOMPTA
open -Wn -a Safari.app http://localhost:3302
kill $!
#open -a Safari.app http://localhost:3302/$!
#pkill -f "afri_compta.rb"
echo Done with AfriCompta
#read a
