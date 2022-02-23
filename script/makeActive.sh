#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2086,SC2230,SC2009,SC2206,SC2062,SC2059

#Copy the iptables line below for every relay which connects to your node and place it's IP in "YOUR-RELAY-IP" and uncomment it
echo "--- MAKING ACTIVE ---"
#iptables -D INPUT -s YOUR-RELAY-IP -p tcp --dport YOUR-NODE-PORT -j DROP
