#!/bin/bash

docker run -p 8080:80 \
    -e AWS_AWSTATS_CONFIG="regenerate" \
    -e AWS_AWSTATS_HOSTNAME="my-bucket.s3.amazonaws.com" \
    -e AWS_AWSTATS_SHORTNAME="my-bucket" \
    -e AWS_AWSTATS_HOSTALIASES="my-bucket.s3.eu-west-2.amazonaws.com s3.eu-west-2.amazonaws.com" \
    -e AWS_AWSTATS_LOG_BUCKET="my-logs-bucket" \
    -e AWS_AWSTATS_LOG_PREFIX="my-logs-prefix" \
    -e AWS_ACCESS_KEY_ID="_secret_key_id_" \
    -e AWS_SECRET_ACCESS_KEY="_secret_key_" \
    -v aws-stats-01-input:/var/awstats-input -v aws-stats-01-db:/var/awstats-db . $@
