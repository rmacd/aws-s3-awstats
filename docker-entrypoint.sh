#!/bin/sh

set -e

exit_func() {
    echo "SIGTERM detected"            
    exit 1
}
trap exit_func SIGTERM SIGINT

DRY_RUN=0
if expr "$AWS_AWSTATS_DRY_RUN" : "true" 1>/dev/null; then
    DRY_RUN=1;
    echo "Dry run ENABLED";
fi

VOLUME_INPUT="/var/awstats-input"
VOLUME_DB="/var/awstats-db"

## function defs
function awstats_config_check() {
    if [ -z "$AWS_AWSTATS_HOSTNAME" ] ; then
        echo "AWS_AWSTATS_HOSTNAME missing" >&2
        exit 1
    fi
    if [ -z "$AWS_AWSTATS_SHORTNAME" ] ; then
        echo "AWS_AWSTATS_SHORTNAME missing" >&2
        exit 1
    fi
    if [ ! -d "$VOLUME_DB/data" ] ; then
        mkdir "$VOLUME_DB/data"
    fi
}

function awstats_www_setup() {
    REGENERATE=0
    if expr "$AWS_AWSTATS_CONFIG" : "regenerate$" 1>/dev/null; then
        REGENERATE=1;
    fi
    if [ ! -f "$VOLUME_DB/awstats.conf" -o "$REGENERATE" -eq 1 ] ; then
        echo "Writing new awstats config ..."
        awstats_config_check
        cat /awstats.template.conf | sed "
            s/AWS_AWSTATS_HOSTNAME/$AWS_AWSTATS_HOSTNAME/g ;
            s/AWS_AWSTATS_SHORTNAME/$AWS_AWSTATS_SHORTNAME/g ;
            s/AWS_AWSTATS_HOSTALIASES/$AWS_AWSTATS_HOSTALIASES/g ;
            /^#/d ; /^\s*$/d" > "$VOLUME_DB/awstats.conf"
    fi
    if [ ! -f "/etc/awstats/awstats.conf" ] ; then
        cp -v "$VOLUME_DB/awstats.conf" /etc/awstats/awstats.conf
    fi
}

if expr "$1" : "serve" 1>/dev/null; then
    awstats_www_setup
    exec /usr/sbin/httpd -D FOREGROUND -f /etc/apache2/httpd.conf
    echo "Exiting web server"
    exit 0
fi

if [ ! -d "/var/awstats-input" -o ! -d "/var/awstats-db" ] ; then
    echo "Logs and/or stats volume not set, please see documentation" >&2
    exit 1
fi

if [ -z "$AWS_ACCESS_KEY_ID" -o -z "$AWS_SECRET_ACCESS_KEY" ] ; then
    echo "AWS parameters missing" >&2
    exit 1
fi

if [ -z "$AWS_AWSTATS_LOG_BUCKET" ] ; then
    echo "AWS bucket name missing" >&2
    exit 1
fi

if [ ! -d "$VOLUME_DB/data" ] ; then
    echo "data directory does not exist, creating ..."
    mkdir "$VOLUME_DB/data"
fi

## Step 2: set up input directories
if [ ! -d "$VOLUME_INPUT/new" ] ; then
    mkdir "$VOLUME_INPUT/new"
fi
if [ ! -d "$VOLUME_INPUT/in-progress" ] ; then
    mkdir "$VOLUME_INPUT/in-progress"
fi
if [ ! -d "$VOLUME_INPUT/processed" ] ; then
    mkdir "$VOLUME_INPUT/processed"
fi

echo "Starting log processing ..."
WORKING_DIRECTORY=$(mktemp -d) || exit 1
echo "Work dir: $WORKING_DIRECTORY"

if [ $DRY_RUN -eq 1 ] ; then
    echo "Dry run: only copying files"
    aws s3 cp "s3://$AWS_AWSTATS_LOG_BUCKET/" "$VOLUME_INPUT/new" --recursive --exclude "*" --include "$AWS_AWSTATS_LOG_PREFIX*"
else
    aws s3 mv "s3://$AWS_AWSTATS_LOG_BUCKET/" "$VOLUME_INPUT/new" --recursive --exclude "*" --include "$AWS_AWSTATS_LOG_PREFIX*"
fi

DESTINATION="$(date +%s).log"
echo "Will write any new entries to $DESTINATION"
/usr/bin/logresolvemerge.pl addfolder=/var/awstats-input/new > "$VOLUME_INPUT/in-progress/$DESTINATION"
find "$VOLUME_INPUT/new" -type f -delete

NUM_NEW_ENTRIES=$(cat "$VOLUME_INPUT/in-progress/$DESTINATION" | wc -l)
echo "Saw $NUM_NEW_ENTRIES new entries"
if [ $NUM_NEW_ENTRIES -gt 0 ] ; then
    awstats.pl -update -config=awstats.conf -LogFile="$VOLUME_INPUT/in-progress/$DESTINATION" -showdropped
    mv "$VOLUME_INPUT/in-progress/$DESTINATION" "$VOLUME_INPUT/processed/$DESTINATION"
fi

