#!/bin/bash
USER=$1
HOST=$2
FILESPEC=$3

RESULT=1
while [ $RESULT = 1 ]
do
    sleep 1
    ssh $USER@$HOST "test -e $FILESPEC"
    RESULT=$?
done
