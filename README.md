# Cardano-Simple-Failover
Simplest possible failover approach which purely runs on the Standby Producer Instance.

## Disclaimer
There is no warranty for the function of this script. Use it at your own risk. Validate proper function.

## How it works?
The Standby Producer Node pings the Master Producer Node every Minute.
If the PING is not successful for several times the Standby is activating itself.
As soon as another PING is successful the Standby turns inactive again.

Note: Ping is executed through CNCLI Ping

Making active and passive is done through FW rules in this approach. The idea is that both Nodes run at any time. The standby is just blocked from propagating Blocks if the Master is working properly.

## Known Limitations

CNCLI Ping is not validating if the node is in sync, just if it is able to communicate.
This means: If the Master Producer comes back online, the Standby Producer will move to standby while the Master Producer still might be syncing
This is only a problem if the Master Producer is down for a longer time period.

## Setup

1. Preconditions - Standby Producer needs to be able to PING Master Producer
```
# Run CNCLI Ping on the Standby Producer and Ping the master
cncli ping --host YOUR-HOST-IP --port YOUR-HOST-PORT
```

2. On the Standby Producer create a folder which will contain the script
```
mkdir -p /opt/cardano/cnode/custom/simple-failover
cd /opt/cardano/cnode/custom/simple-failover
```

3. Download the files and make them executeable
```
wget https://raw.githubusercontent.com/ResponsibleStaking/Cardano-Simple-Failover/main/script/checkStatus.sh
wget https://raw.githubusercontent.com/ResponsibleStaking/Cardano-Simple-Failover/main/script/makeActive.sh
wget https://raw.githubusercontent.com/ResponsibleStaking/Cardano-Simple-Failover/main/script/makeStandby.sh

chmod +x checkStatus.sh
chmod +x makeActive.sh
chmod +x makeStandby.sh
```

4. Customize the variables in makeStandby.sh
```
sudo nano checkStatus.sh

#Customize the Variables on top of the file
MASTER_NODE_IP=1.2.3.4
MASTER_NODE_PORT=6000

CNCLI_SCRIPT=/home/markus/.cargo/bin/cncli
SCRIPT_ROOT=/opt/cardano/cnode/custom/simple-failover

MAX_FAILURE_COUNT=3
```

5. Customize the makeActive and makeStandby Scripts to reflect your Setup
```
#Customize makeActive to your needs
nano makeActive.sh

#Customize makeStandby to your needs
nano makeStandby.sh
```

6. Validate function of makeActive and makeStandby
```
sudo ./makeStandby.sh
#check if the IN connections of the Standby Producer Node are going away in gLiveView

sudo ./makeActive.sh
#check if the IN connections of the Standby Producer Node are going away in gLiveView
```

7. Create a Service which calls the script every minute
```
cd /etc/systemd/system
sudo wget https://raw.githubusercontent.com/ResponsibleStaking/Cardano-Simple-Failover/main/service/simple-cardano-failover.service
sudo wget https://raw.githubusercontent.com/ResponsibleStaking/Cardano-Simple-Failover/main/service/simple-cardano-failover.timer
```
If you customized the paths you need to change them in failover-cardano.service as well
Then enable the Service
```
sudo systemctl enable simple-cardano-failover.service
sudo systemctl start simple-cardano-failover.service

sudo systemctl enable simple-cardano-failover.timer
sudo systemctl start simple-cardano-failover.timer
```
Check if the service is ACTIVE
```
sudo systemctl status simple-cardano-failover.service
```

8. Final check
Check incoming connections on your failover node through:
```
cat failure.status
cat failure.count
netstat -antpe | grep cardano-node
```
When the server is active there should not be any IN connections from your relays.
When the server is standby there should be IN connections from your relays.

9. Debugging
To see what happens you can take a look on the Logs of crontab
```
sudo journalctl -u simple-cardano-failover -b
```
