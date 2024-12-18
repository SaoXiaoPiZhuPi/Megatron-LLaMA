#!/bin/bash

dp=2
while [ $dp -le 8 ]; do
    tp=1
    while [ $tp -le $((8 / dp)) ]; do
        pp=$((8 / dp / tp))
        bash LLaMA_20B.sh $tp $pp $dp
        tp=$((tp * 2))
    done
    dp=$((dp * 2))
done
