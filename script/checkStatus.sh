#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2086,SC2230,SC2009,SC2206,SC2062,SC2059

MASTER_NODE_IP=1.2.3.4
MASTER_NODE_PORT=6000

CNCLI_SCRIPT=/home/markus/.cargo/bin/cncli
SCRIPT_ROOT=/opt/cardano/cnode/custom/simple-failover

MAX_FAILURE_COUNT=3
MIN_OK_COUNT=10

######################################
# Do NOT modify code below           #
######################################

#Initialize Counter file if not exists
counterFilePath="$SCRIPT_ROOT/failure.count"
if [ ! -f "$counterFilePath" ]; then
    echo "Initializing failure counter file"
    echo "0">$counterFilePath
fi

counterOkFilePath="$SCRIPT_ROOT/failure.okcount"
if [ ! -f "$counterOkFilePath" ]; then
    echo "Initializing ok counter file"
    echo "$MIN_OK_COUNT">$counterOkFilePath
fi

#Initialize Status file if not exists
statusFilePath="$SCRIPT_ROOT/failure.status"
if [ ! -f "$statusFilePath" ]; then
    echo "Initializing status file"
    echo "unknown">$statusFilePath
fi

#Read last status
oldStatus=$(cat $statusFilePath)
newStatus="undetermined"

#Ping the master node to see if it is ok
pingResult=$($CNCLI_SCRIPT ping --host $MASTER_NODE_IP --port $MASTER_NODE_PORT | jq -r '.status')
echo "pingResult: $pingResult"

#Check if Master is OK
if [ "$pingResult" = "ok" ]; then
  #Reset failure counter to 0
  echo "master is OK, setting failure counter to 0 and newStatus to standby"
  echo "0">$counterFilePath

  #Read OK Count
  okCount=$(cat $counterOkFilePath)

  if [ "$okCount" -ge "$MIN_OK_COUNT" ]; then
    #Master is up for enough intervals, going to standby
    echo "OkCount: $okCount >= $MIN_OK_COUNT -> going to standby"
    newStatus="standby"
  else
    #Waiting until master is up for enough intervals, staing active
    echo "OkCount: $okCount < $MIN_OK_COUNT -> staying active a little longer"

    #Increment OK Counter
    okCount=$(expr $okCount + 1)
    echo "$okCount">$counterOkFilePath
    echo "new okCount: $okCount"
    newStatus="active"
  fi

#Master is not OK
else
  echo "master is not OK, increasing count and check if stepping in is required"

  #Setting OK counter to 0 to make it count from 0 once master comes up again
  echo "0">$counterOkFilePath

  #Read failure count
  failureCount=$(cat $counterFilePath)

  #If failure count > maximum failure Count
  if [ "$failureCount" -ge "$MAX_FAILURE_COUNT" ]; then

    #Step in (open up network connections
    echo "Failure count exceeds max Failure Count - setting newStatus to active"
    newStatus="active"

  else
  #Else (maximum failure count not reached, wait)
    #Increase failure count (read, increase, write)
    failureCount=$(expr $failureCount + 1)
    echo "$failureCount">$counterFilePath
    echo "new failureCount: $failureCount"

    #Make passive again
    echo "New failure count does not exceed max Failure Count - keep newStatus on standby"
    newStatus="standby"
  fi
fi

#Check if Status was changed
if [ "$oldStatus" != "$newStatus" ]; then
  echo "Status was changed applying from $oldStatus to $newStatus"

  if [ "$newStatus" == "active" ]; then
    echo "Calling makeActive script"
    $SCRIPT_ROOT/makeActive.sh
  elif [ "$newStatus" == "standby" ]; then
    echo "Calling makeStandby script"
    $SCRIPT_ROOT/makeStandby.sh
  fi

  #Persist new status
  echo "$newStatus">$statusFilePath
else

  echo "Status was not changed. no action required"
fi
