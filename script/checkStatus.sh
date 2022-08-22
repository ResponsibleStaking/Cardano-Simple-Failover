#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2086,SC2230,SC2009,SC2206,SC2062,SC2059

MASTER_NODE_IP=1.2.3.4
MASTER_NODE_PORT=6000
MASTER_NODE_METRICS_PORT=12798

CNCLI_SCRIPT=/home/markus/.cargo/bin/cncli
SCRIPT_ROOT=/opt/cardano/cnode/custom/simple-failover

MAX_FAILURE_COUNT=3
MIN_OK_COUNT=10

MAX_TIP_AGE=900    #in seconds: 900 = 15 Minutes, If age gets > 15 Minutes the error count will start increasing until it reached MAX_FAILURE_COUNT

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

#Evaluate the masters TIP to see if it is ok as well
currentMasterSlot=$(curl -s -m 3 http://$MASTER_NODE_IP:$MASTER_NODE_METRICS_PORT/metrics | grep cardano_node_metrics_slotNum_int | awk '{print $2}')
echo "currentMasterSlot: $currentMasterSlot"

refTip=$(expr $(date +%s) - 1591566291)
echo "refTip: $refTip"

currentMasterTipAge=$(expr $refTip - $currentMasterSlot)
echo "currentMasterTipAge: $currentMasterTipAge"

#Check if the caluclated Tip Age is valid
if [ $currentMasterTipAge -gt 0 ]; then
  #Check if the TIP is not too old to still be OK
  if [ $currentMasterTipAge -le $MAX_TIP_AGE ]; then
    tipResult="ok"
  else
    tipResult="nok"
  fi
else
  tipResult="error"
fi
echo "tipResult: $tipResult"


#Check if Master is OK
if [ "$pingResult" = "ok" ] && [ $tipResult = "ok" ]; then
  echo "master is OK, resetting Failure counter and set newStatus to standby if OK counter is reached"
  echo "0">$counterFilePath

  #Read OK Count
  okCount=$(cat $counterOkFilePath)

  if [ "$okCount" -ge "$MIN_OK_COUNT" ]; then
    #Master is up for enough intervals, going to standby
    echo "Ok count $okCount reached MIN_OK_COUNT $MIN_OK_COUNT - setting newStatus to standby"
    newStatus="standby"
  else
    #Waiting until master is up for enough intervals, staing active
    echo "OkCount: $okCount not reached MIN_OK_COUNT $MIN_OK_COUNT - keep newStatus like it is at $oldStatus"
    #Increment OK Counter
    okCount=$(expr $okCount + 1)
    echo "$okCount">$counterOkFilePath
    echo "new okCount: $okCount"
    newStatus="$oldStatus"
  fi

#Master is not OK
else
  echo "master is not OK, resetting OK count and increasing failure count and check if stepping in is required"
  echo "0">$counterOkFilePath

  #Read failure count
  failureCount=$(cat $counterFilePath)

  if [ "$failureCount" -ge "$MAX_FAILURE_COUNT" ]; then
    #Step in (open up network connections
    echo "Failure count $failureCount reached max Failure Count $MAX_FAILURE_COUNT - setting newStatus to active"
    newStatus="active"
  else
    #Else (maximum failure count not reached, wait)
    echo "Failure count $failureCount not reached max Failure Count $MAX_FAILURE_COUNT - keep newStatus like it is at $oldStatus"
    #Increase and store failure count (read, increase, write)
    failureCount=$(expr $failureCount + 1)
    echo "$failureCount">$counterFilePath
    echo "new failureCount for next check: $failureCount"
    newStatus="$oldStatus"
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

#No matter if the Status was changed make sure that SendTip service is in line with the current status
#Relevant Case: If the Standby Node crashed for any reason and was manually restarted the SendTip service would have been activated. It needs to set inline with the current node status Then
if [ "$newStatus" = "active" ]; then
  #systemctl start cnode-cncli-ptsendtip.service
else
  #systemctl stop cnode-cncli-ptsendtip.service
fi
