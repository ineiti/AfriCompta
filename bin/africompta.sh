#!/usr/bin/env bash
WDIR=$( dirname ${BASH_SOURCE[0]} )
pwd > /tmp/apppwd
echo $WDIR >> /tmp/apppwd

$WDIR/../Resources/AfriCompta/afri_compta.rb
read a