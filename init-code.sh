#!/usr/bin/env bash

# required packages on a clean debian installation:
# subversion autotools-dev autoconf libtool automake
# libexpat1-dev  

CWD=`pwd`
# download ldns code, required by the unbound server
if [ ! -e ldns.svn ]; then
  svn co http://nlnetlabs.nl/svn/ldns/trunk/ ldns.svn
fi

cd ldns.svn
#update svn repo
svn up

if [ ! -e configure ]; then 
  libtoolize -c --install
  autoreconf --install
fi 

#compile data
if [ ! -e Makefile ]; then
  ./configure --disable-gost
fi
make all doc


cd $CWD
#download unbound code 
if [ ! -e unbound.svn ]; then
  svn co http://unbound.nlnetlabs.nl/svn/trunk/ unbound.svn
fi

cd unbound.svn
#update svn repo
svn up
#compile data
if [ ! -e Makefile ]; then
  ./configure --disable-gost --with-ldns=../ldns.svn/ --with-pythonmodule --with-pyunbound
fi
make

cd $CWD
