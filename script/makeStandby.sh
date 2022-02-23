#Copy the iptables line below for every relay which connects to your node and place it's IP in "YOUR-RELAY-IP" and uncomment it
echo "MAKING STANDBY"
iptables -I INPUT -s YOUR-RELAY-IP -p tcp --dport YOUR-NODE-PORT -j DROP
