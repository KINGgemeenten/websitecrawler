#!/bin/bash

(
  # Obtain an exclusive lock, give up if unable (non-block)
  if flock -x -n 200
  then
    # Check if there are URL's for one time free generation
    if [ "$(ls -A free_urls/)" ]
    then
      # Generate filtered and normalized segment from the seed list
      bin/nutch freegen  free_urls/ crawl/segments/ -filter -normalize

      # Remove the seed lists
      rm free_urls/*
    else
      # Generate a fetch list (list of URL's to download) from the CrawlDB
      bin/nutch generate crawl/crawldb crawl/segments -noFilter -noNorm -numFetchers 1 -adddays 0 -topN 40000
    fi

    # Check if we got a valid fetch list
    if [ $? -ne 0 ]
    then
      echo "No fetch list generated"
      exit
    fi

    # Get the newly created segement
    SEGMENT=crawl/segments/`ls -tr crawl/segments|tail -1`

    # Fetch (download and parse) the previously generated segment
    bin/nutch fetch $SEGMENT

    # We no longer need the segment's fetch list, free some bytes
    rm -r $SEGMENT/crawl_generate

    # Update the CrawlDB with the fetched records and newly discovered URL's
    bin/nutch updatedb crawl/crawldb $SEGMENT

    # Write the segment to the configured indexing backend
    bin/nutch index -Dindexer.skip.notmodified=true crawl/crawldb $SEGMENT -deleteGone

    # Delete any Hadoop tmp directory
    rm -rf /tmp/hadoop-$USER
  fi
) 200>/var/lock/run-crawl.lock
