#!/usr/bin/env bash

sif='src/R.sif'

if test -f ${sif}; then
    echo 'R.sif already downloaded'
else
    id='77DD71E598E5B51B'
    url="https://onedrive.live.com/download?cid=${id}&resid=${id}%2125060&authkey=AP38vvJ187Mq-fM"
    wget -O ${sif} ${url}
fi

if test $(md5sum ${sif} | awk '{print $1}') == '141b1340630f6d20ad1dd106b014f8c3'; then
    echo 'MD5 sum for R.sif passes'
fi