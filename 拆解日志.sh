#!/bin/sh
logs_path="/home/hadoop/nginx/logs/"
pid_path="/home/hadoop/nginx/logs/nginx.pid"
filepath=${logs_path}"access.log"
echo $filepath
mv ${logs_path}access.log ${logs_path}access_$(date -d '-1 day' '+%Y-%m-%d-%H-%M').log
kill -USR1 `cat ${pid_path}`