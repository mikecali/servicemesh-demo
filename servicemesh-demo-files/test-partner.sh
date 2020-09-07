#!/bin/bash

url=partner-$Pdemo-istio-system.$APP_SUBDOMAIN
i=0
while :
do
  echo Request Number $i:
  ((i++))
  curl $url
  echo ""
  #sleep 1
done
