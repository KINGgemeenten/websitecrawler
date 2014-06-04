#!/bin/bash

# Get the number of segments
let "numSegments = `ls -1 crawl/segments/ | wc -l`"

echo Reindexing $numSegments segments..

# Traverse through the list of segments
for file in `ls crawl/segments/ | sort ` ; do

 echo $numSegments: indexing $file..

 # Send the segments to the index
 bin/nutch index -Dindexer.skip.notmodified=false crawl/crawldb crawl/segments/$file -deleteGone

 # Decrement the number of segments
 let "numSegments -= 1"

done

echo Done.

