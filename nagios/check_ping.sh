#!/bin/bash

#hardcoded 
server_ip='192.28.54.117'

lost_packets=`ping -c 4 $server_ip | grep 'received' | awk -F ',' '{print $3}' | awk -F ' ' '{print $1}' | tr -d '%'`

if (( $lost_packets == 100 )); then
   echo "CRITICAL - $server_ip full packet loss ($lost_packets%)."
   exit 2
elif (( 76<=$lost_packets && $lost_packets<=99 )); then
   echo "CRITICAL - $server_ip severe packet loss ($lost_packets%)."
   exit 2
elif (( 51<=$lost_packets && $lost_packets<=75 )); then
   echo "Warning - $server_ip large packet loss ($lost_packets%)."
   exit 1
elif (( 26<=$lost_packets && $lost_packets<=50 )); then
   echo "Warning - $server_ip minor packet loss ($lost_packets%)."
   exit 1
elif (( 1<=$lost_packets && $lost_packets<=25 )); then
   echo "Warning - $server_ip minor packet loss ($lost_packets%)."
   exit 1
elif (( $lost_packets == 0 )); then
   echo "OK - $server_ip no packet loss ($lost_packets%)"
   exit 0
else
   echo "WARNING - $server_ip unknown packet loss ($lost_packets%)"
   exit 3
fi
