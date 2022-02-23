MASTER_NODE_IP=1.2.3.4
MASTER_NODE_PORT=6000

CNCLI_SCRIPT=/home/markus/.cargo/bin/cncli
SCRIPT_ROOT=/opt/cardano/cnode/custom/simple-failover

MAX_FAILURE_COUNT=3

######################################
# Do NOT modify code below           #
######################################

#Initialize Counter file if not exists
counterFilePath="$SCRIPT_ROOT/failure.count"
if [ ! -f "$counterFilePath" ]; then
    echo "Initializing counter file"
    echo "0">$counterFilePath
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
  echo "master is OK, setting counter to 0 and newStatus to standby"
  echo "0">$counterFilePath
  newStatus="standby"

#Master is not OK
else
  echo "master is not OK, increasing count and check if stepping in is required"

  #Increase failure count (read, increase, write)
  failureCount=$(cat $counterFilePath)
  failureCount=$(expr $failureCount + 1)
  echo "$failureCount">$counterFilePath
  echo "new failureCount: $failureCount"


  #If failure count > maximum failure Count
  if [ "$failureCount" -gt "$MAX_FAILURE_COUNT" ]; then

    #Step in (open up network connections
    echo "New failure count exceeds max Failure Count - setting newStatus to active"
    newStatus="active"

  else
  #Else (maximum failure count not reached, wait)

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
