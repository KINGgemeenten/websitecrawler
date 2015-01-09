#!/bin/bash

# Fetch Nutch 1.8 sources
wget http://archive.apache.org/dist/nutch/1.8/apache-nutch-1.8-src.tar.gz
#wget http://apache.cs.uu.nl/dist/nutch/1.9/apache-nutch-1.9-src.tar.gz

# Get rid of old stuff
rm -rf apache-nutch-1.8

# Unpack and get rid of archive
tar -xvzf apache-nutch-1.8-src.tar.gz
rm apache-nutch-1.8-src.tar.gz
cd apache-nutch-1.8

# Apply patches
for patch in `ls ../patches` ; do
  patch -p0 < ../patches/$patch
done

# Copy configuration
cp -r ../conf/ .

# Build
ant

# Copy some runtime scripts
cp -r ../scripts/* runtime/local

# Make some runtime dirs available
mkdir runtime/local/free_urls/
cp -r ../inject_urls runtime/local

# Upload to the cluster
scp runtime/deploy/apache-nutch-1.8.job hadoop@vps2868.directvps.nl:/opt/nutch/
