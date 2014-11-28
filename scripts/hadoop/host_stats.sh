#!/bin/sh

# Get rid of current dump
rm -f host_stats.txt

# Collect host statistics
bin/nutch org.apache.nutch.util.domain.DomainStatistics crawl/crawldb/current/ dumps/host_stats host

# Copy to local
hadoop fs -get dumps/host_stats/part-r-00000 host_stats.txt

# Remove from HDFS
hadoop fs -rmr dumps/host_stats
