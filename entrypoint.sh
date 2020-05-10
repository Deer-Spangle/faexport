#!/bin/sh

#check if REDIS_URL is empty
if [  -z "$REDIS_URL" ]; then
    #run the redis-server in the background
    redis-server &
fi

#run faexport and listen on all ips and port 9292
bundle exec thin -R config.ru start --threaded -p 9292
