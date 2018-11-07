#!/bin/bash

function start_node {
  mkdir $1
  cd $1
  zold remote clean
  zold node $3 --nohup --nohup-command='touch restarted' --nohup-log=log --nohup-max-cycles=0 --nohup-log-truncate=10240 \
    --expose-version=$2 --save-pid=pid --routine-immediately \
    --verbose --trace --invoice=REDEPLOY@ffffffffffffffff \
    --host=localhost --port=$1 --bind-port=$1 --threads=0 > /dev/null 2>&1
  wait_for_port $1
  cat pid
  cd ..
}

echo "Installing old version of zold"
gem install zold --version 0.0.1

high=$(reserve_port)
primary=$(start_node ${high} 9.9.9 --standalone)

low=$(reserve_port)
secondary=$(start_node ${low} 1.1.1)
zold remote add localhost ${high} --home=${low} --skip-ping

trap "halt_nodes ${high}" EXIT

wait_for_file ${low}/restarted

echo "Check if old version has been uninstalled"
zold_gems=$(gem list zold)
if [[ "${zold_gems}" == *"zold"* ]]; then
   echo "Old versions of Zold gem have not been uninstalled"
   exit 16
fi
sleep 5

echo "High node logs (port ${high}):"
cat ${high}/log
echo "Low node logs (port ${low}):"
cat ${low}/log
