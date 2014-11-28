#!/bin/sh

# This script creates a temp directory for yesterday's segments and copies
# yesterday's segments to it. Those segments are then merged to another
# temporary directory. The final merged segment is then copied over to
# the day queue in /segments/retired/. There they wait to be merged into
# a monthly segment.

# TODO: set mappers and reducers

if [ $# = 0 ]
then
  # Yesterday's date as represented in segment names e.g. 20131219
  YESTERDAY=`date -d yesterday +%Y%m%d`
else
  YESTERDAY=`date -d "$1 day ago" +%Y%m%d`
  if [ $? -ne 0 ]
  then
    echo Invalid date string
    exit
  fi
fi

# The glob of yesterday's segments in incoming, we copy these
INCOMING_SEGMENTS=segments/finished/${YESTERDAY}*

# Temporary directory containing unmerged segments
TEMP_INPUT_DIR=segments/temp_unmerged_${YESTERDAY}

# Temporary directory containing the newly merged segment
TEMP_OUTPUT_DIR=segments/temp_merged_${YESTERDAY}

# The final segments path and name in /retired
RETIRED_SEGMENT_NAME=segments/retired/${YESTERDAY}

# Gather error message here
ERROR=""

# Testing if there are segments to merge at all
if [ `hadoop fs -ls $INCOMING_SEGMENTS | wc -l` -eq 0 ]
then
  echo No segments to merge..
  exit
fi

echo Making temporary directory for $TEMP_INPUT_DIR
hadoop fs -mkdir $TEMP_INPUT_DIR

if [ $? -eq 0 ]
then
  echo Moving $INCOMING_SEGMENTS to $TEMP_INPUT_DIR
  hadoop fs -mv $INCOMING_SEGMENTS $TEMP_INPUT_DIR

  if [ $? -eq 0 ]
  then
    echo Merging segments $TEMP_INPUT_DIR to $TEMP_OUTPUT_DIR
    bin/nutch mergesegs $TEMP_OUTPUT_DIR -dir $TEMP_INPUT_DIR

    if [ $? -eq 0 ]
    then
      MERGED_SEGMENT=/`hadoop fs -ls $TEMP_OUTPUT_DIR | cut -s -d / -f 2-7`
      echo Copying $MERGED_SEGMENT to retirement $RETIRED_SEGMENT_NAME
      hadoop fs -mv $MERGED_SEGMENT $RETIRED_SEGMENT_NAME

      if [ $? -eq 0 ]
      then
        echo Removing temporary directory $TEMP_INPUT_DIR and $TEMP_OUTPUT_DIR
        hadoop fs -rmr $TEMP_INPUT_DIR $TEMP_OUTPUT_DIR
      else
        ERROR="Step 4/4: Moving merged segment to retirement $RETIRED_SEGMENT_NAME"
        hadoop fs -mv $TEMP_INPUT_DIR/* segments/finished/
        hadoop fs -rmr $TEMP_INPUT_DIR $TEMP_OUTPUT_DIR
      fi
    else
      ERROR="Step 3/4: Merging segments $TEMP_INPUT_DIR to $TEMP_OUTPUT_DIR failed"
      hadoop fs -mv $TEMP_INPUT_DIR/* segments/finished/
      hadoop fs -rmr $TEMP_INPUT_DIR $TEMP_OUTPUT_DIR
    fi
  else
    ERROR="Step 2/4: Moving $INCOMING_SEGMENTS to $TEMP_INPUT_DIR failed"
  fi
else
  ERROR="Step 1/4: Making temporary directory $TEMP_INPUT_DIR failed"
fi

# Got an error?
if [ -n "$ERROR" ]
then
  echo $ERROR | mail -r noreply-`hostname`@openindex.io -s "Error daily merging on `hostname`" systems@openindex.io
fi
