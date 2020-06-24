## AWS -> awstats processor

**NOTE** this assumes you are using a single bucket for your logs, separate
from the data bucket(s) you are logging access to.

You can use a 'prefix' (set up via your bucket configuration) to process logs
separately but allow them to be written to a single bucket.

### Volumes

Image must be run with 2x volumes; one mapped to `/var/awstats-input` (into
which all raw logs will be written), and another mapped to `/var/awstats-db`
(into which all the awstats data will be written).

Actions

- creates config if not already exists

### Image Variables

**Mandatory variables**
`AWS_ACCESS_KEY_ID` - bucket access key ID
`AWS_SECRET_ACCESS_KEY` - bucket access key secret
`AWS_AWSTATS_LOG_BUCKET` - logs bucket name

**First-run only** (can be omitted if awstats has already been run)
`AWS_AWSTATS_HOSTNAME` - bucket for which these stats are being run (ie the main bucket)
`AWS_AWSTATS_SHORTNAME` - friendly name for the stats (will default to ??) 

**Optional first-run only**
`AWS_AWSTATS_HOSTALIASES` - any aliases used to access the same bucket (eg via CloudFront)
`AWS_AWSTATS_CONFIG` - if set to 'regenerate' then force the awstats.conf file to be overwritten

    **NB** host information for admin tasks: s3.eu-west-2.amazonaws.com


`AWS_AWSTATS_LOG_PREFIX` - if set, grabs logs only matching a particular prefix


### Example runtime config

```
docker run -it -e AWS_ACCESS_KEY_ID="_MY_KEY_ID" \
    -e AWS_SECRET_ACCESS_KEY="_MY_KEY_SECRET" \
    -v aws-stats-01-input:/var/awstats-input \
    -v aws-stats-01-db:/var/awstats-db
```
