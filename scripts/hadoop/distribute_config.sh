#!/bin/sh
for I in `cat /opt/hadoop/hadoop/conf/slaves | sort`;
do
  echo Pushing Nutch config to $I..

  scp /opt/nutch/conf/* hadoop@$I:/opt/hadoop/hadoop/conf/
done

