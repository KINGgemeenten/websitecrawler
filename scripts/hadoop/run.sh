#!/bin/bash
(
  # Obtain an exclusive lock, give up if unable (non-block)
  if flock -x -n 200
  then
    # Check for updated inject URL's and domain URL filter
    echo Downloading updated seed.txt
    if curl -s -f http://gewoontoegankelijk.nl/seed.txt > seed.txt.new
    then
      # Check it has changed
      if ! diff -q /opt/nutch/seeds/seed.txt seed.txt.new
      then
        # Attempt to fetch the other file
        echo Downloading domain-urlfilter.txt
        if curl -s -f http://gewoontoegankelijk.nl/domain-urlfilter.txt > domain-urlfilter.txt.new
        then
          # Check domain URL filter has changed
          if ! diff -q /opt/nutch/conf/domain-urlfilter.txt domain-urlfilter.txt.new
          then
            # And if all lines have at least one dot
#            if [ `grep "\n" domain-urlfilter.txt.new |  wc -l` -eq `grep . domain-urlfilter.txt.new |  wc -l` ]
#            then
              # Copy stuff to their new home
              mv seed.txt.new /opt/nutch/seeds/seed.txt
              mv domain-urlfilter.txt.new /opt/nutch/conf/domain-urlfilter.txt

              # Distribute the config to the worker nodes
              distribute_config.sh

              # Inject some
              inject.sh
#            else
#              echo Domain-urlfilter.txt does not conform to specs
#            fi
          else
            echo Domain-urlfilter.txt has not changed
          fi
        else
          echo Could not download domain-urlfilter.txt
        fi
      else
        echo Seed.txt has not changed
      fi
    else
      echo Could not download seed.txt
    fi

    # Remove temp crap if it's still there
    rm -f seed.txt.new domain-urlfilter.txt.new

    # Check if there are URL's for free generation
    if [ "$(ls -A urls/)" ]
    then
      # Traverse through the list of seed list files
      for file in `ls urls/` ;
      do
        # Copy the seed list to HDFS
        hadoop fs -put urls/$file seeds/

        # Remove the seed list locally
        rm urls/$file &

        # Generate filtered and normalized segment from the seed list
        nutch freegen seeds/ segments/generate/ -filter -normalize

        # Move the generated segment to the fetch queue
        hadoop fs -mv segments/generate/* segments/fetch &

        # Remove the seed list from HDFS
        hadoop fs -rm -skipTrash seeds/$file &
      done
    fi

    # Generate a fetch list (list of URL's to download) from the CrawlDB
    nutch generate crawl/crawldb segments/generate/ -noFilter -noNorm -numFetchers 4

    # Check if we got a valid fetch list
    if [ $? -ne 0 ]
    then
      echo "No fetch list generated"
      exit
    fi

    # Move the generated segment(s) to the fetch queue
    hadoop fs -mv segments/generate/* segments/fetch/

    # Traverse through the list of segments
    for file in `hadoop fs -ls segments/fetch/ | grep segments | cut -d / -f 6` ; do
      # Fetch (download and parse) the previously generated segment
      nutch fetch segments/fetch/$file

      # We don't need the generated fetch lists anymore
      hadoop fs -rmr -skipTrash segments/fetch/$file/crawl_generate

      # Move the fetched segment to the update queue
      hadoop fs -mv segments/fetch/$file segments/update/
    done

    # Update the CrawlDB with the fetched records and newly discovered URL's
    nutch updatedb -Dplugin.includes="urlfilter-(domain|suffix)" crawl/crawldb -dir segments/update/ -filter

    # Send the stuff to the index
    nutch index -Dmapred.reduce.tasks=12 crawl/crawldb -dir segments/update -deleteGone -noCommit

    # Move the finished segments to their daily finished queue
    hadoop fs -mv segments/update/* segments/finished/ &
  fi
) 200>/var/lock/run-crawl.lock
