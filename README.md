# Cardano-Simple-Failover
Simpliest possible failover approach which purely runs on the Standby Producer Instance.

## Disclaimer
There is no warranty for the function of this script. Use it on your on risk. Validate proper function.

## How it works?
The Standby Producer Node pings the Master Producer Node every Minute.
If the PING is not successful for several times the Standby is activating itself.
As soon as another PING is successful the Standby turns inactive again.

Note: Ping is executed through CNCLI Ping


## Setup

1. Preconditions - Standby Producer needs to be able to PING Master Producer
```
# Run CNCLI Ping on the Standby Producer and Ping the master
cncli ping --host YOUR-HOST-ID --port YOUR-HOST-PORT
```

2. On the Standby Producer create a folder which will contain the script
```
mkdir -R /opt/cardano/cnode/custom/simple-failover
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
nano checkStatus.sh

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
./makeStandby.sh
#check if the IN connections of the Standby Producer Node are going away in gLiveView

./makeActive.sh
#check if the IN connections of the Standby Producer Node are going away in gLiveView
```

6. Create a Crontab Job which triggers the code
```
crontab -u user -e

* * * * * /opt/cardano/cnode/custom/simple-failover/checkStatus.sh
```
