#!/bin/bash

(
  # Obtain an exclusive lock, give up if unable (non-block)
  if flock -x -n 200
  then
    # Check for updated inject URL's and domain URL filter
    echo Downloading updated seed.txt
    if curl -s -f http://example.org/ > seed.txt.new
    then
      # Check it has changed
      if ! diff -q inject_urls/seed.txt seed.txt.new
      then
        # Attempt to fetch the other file
        echo Downloading domain-urlfilter.txt
        if curl -s -f http://example.org/ > domain-urlfilter.txt.new
        then
          # Check domain URL filter has changed
          if ! diff -q conf/domain-urlfilter.txt domain-urlfilter.txt.new
          then
            # And if all lines have at least one dot
            if [ `grep "\n" domain-urlfilter.txt.new |  wc -l` -eq `grep . domain-urlfilter.txt.new |  wc -l` ]
            then
              # Copy stuff to their new home
#              mv seed.txt.new inject_urls/seed.txt
#              mv domain-urlfilter.txt.new conf/domain-urlfilter.txt

              # Inject some
echo              ./inject.sh
            else
              echo Domain-urlfilter.txt does not conform to specs
            fi
          else
            echo Domain-urlfilter.txt has not changed
          fi
        else
          echo Could not download domain-urlfilter.txt
        fi
      else
        echo Seed.txt has not changed
      fi
      echo Could not download seed.txt
    fi

    # Remove temp crap if it's still there
    rm -f seed.txt.new domain-urlfilter.txt.new

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
