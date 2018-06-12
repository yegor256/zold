#!/bin/bash

port=$(reserve_port)

mkdir server
cd server
zold node --trace --invoice=NOPREFIX@ffffffffffffffff \
  --host=localhost --port=${port} --bind-port=${port} \
  --threads=0 --standalone &
pid=$!
trap "kill -9 $pid" EXIT
cd ..

while ! nc -z localhost ${port}; do
  sleep 0.5
  ((c++)) && ((c==20)) && break
done

zold remote clean
zold remote add localhost ${port}
zold remote trim
zold remote show

zold --public-key=id_rsa.pub create 0000000000000000
target=$(zold create --public-key=id_rsa.pub)
invoice=$(zold invoice ${target})
zold pay --private-key=id_rsa 0000000000000000 ${invoice} 14.99 'To save the world!'
zold propagate 0000000000000000
zold show
zold show 0000000000000000
zold taxes debt 0000000000000000

zold remote show
zold push 0000000000000000 --sync
zold fetch 0000000000000000 --ignore-score-weakness
zold diff 0000000000000000
zold merge 0000000000000000
zold clean 0000000000000000
