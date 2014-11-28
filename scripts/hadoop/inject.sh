#!/bin/sh
# Upload local seeds to HDFS
hadoop fs -put seeds/* seeds/

# Perform the inject job
nutch inject crawl/crawldb seeds/

# Get rid of seeds left on HDFS but keep local copy
hadoop fs -rm seeds/*
