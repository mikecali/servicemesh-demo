#!/bin/bash

url=customer-anz-servicemesh-demo-istio-system.apps.cluster-e890.e890.sandbox1543.opentlc.com
i=0
while :
do
  echo Request Number $i:
  ((i++))
  curl $url
  echo ""
  #sleep 1
done
