#!/bin/bash

server_ip=$1
amount_of_pings=$2

if [ ! $# == 2 ]; then
  echo "CRITICAL - Usage: $0 ip_address amount_of_packets"
  exit 2
fi

check_if_ip=$(echo $server_ip | grep '^[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}$')
check_if_number=$(echo $amount_of_pings | grep -E '^[0-9]+$')

if [ $check_if_ip ]; then
   if [ $check_if_number ]; then

        lost_packets=`ping -c $amount_of_pings -W 4 $server_ip | grep 'received' | awk -F ',' '{print $3}' | awk -F ' ' '{print $1}' | tr -d '%'`

           if (( $lost_packets == 100 )); then
              echo "CRITICAL - $server_ip no connection ($lost_packets%)."
              exit 2
           elif (( 76<=$lost_packets && $lost_packets<=99 )); then
              echo "CRITICAL - $server_ip severe packet loss ($lost_packets%)."
              exit 2
           elif (( 51<=$lost_packets && $lost_packets<=75 )); then
              echo "Warning - $server_ip major packet loss ($lost_packets%)."
              exit 1
           elif (( 26<=$lost_packets && $lost_packets<=50 )); then
              echo "Warning - $server_ip medium packet loss ($lost_packets%)."
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
   else
        echo "CRITICAL - Packet amount is not a number"
        exit 2
   fi
else
   echo "CRITICAL - $server_ip does not match ip address"
   exit 2
fi
