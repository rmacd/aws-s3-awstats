# AWS S3 to AWStats processor

**What is it?**

Takes your AWS S3 logs, collates them, and then serves them via AWStats. Includes support for GeoIP (Cities / Countries) via GeoLite2.

> **NOTE** this assumes you are using a single bucket for your logs, separate from the data bucket(s) you are logging access to.
>
> You can use a 'prefix' (set up via your bucket configuration) to process logs separately but allow them to be written to a single bucket.

## Getting started

The image has two 'components': the web server + awstats, and the log processor.

**When logs are being processed**, the image attempts to connect to your AWS S3 logs bucket, collate the logs, and then update the attached AWStats instance.

**When the image is launched via the `serve` option** the Apache2 instance starts listening for connections to `/cgi-bin/awstats.pl`. This can be placed behind a reverse proxy + some authentication.

### Volumes

| Volume               | Purpose                                                      |
| -------------------- | ------------------------------------------------------------ |
| `/var/awstats-input` | Holds all the log files (new, in-progress, processed)        |
| `/var/awstats-db`    | Holds all the AWStats data, including DNS cache file(s), log databases, etc |

### Environment Variables

Global variables

| Name                  | Options / Example | Mandatory | Purpose                                                      |
| --------------------- | ----------------- | --------- | ------------------------------------------------------------ |
| `AWS_AWSTATS_DRY_RUN` | [\|true]          | no        | When set to 'true', copies (rather than moves) log files from S3. All the rest of the process executes as normal. |
| `AWS_AWSTATS_CONFIG`  | [\|regenerate]    | no        | When set to 'regenerate', forces regeneration of `awstats.conf` file (see next section, as those variables will then be required) |

#### When generating `awstats.conf ` (or on first run):

| Name                      | Options / Example                                          | Mandatory | Purpose                                                      |
| ------------------------- | ---------------------------------------------------------- | --------- | ------------------------------------------------------------ |
| `AWS_AWSTATS_HOSTNAME`    | `mybucket.s3.amazon.com`                                   | yes       | "Main" hostname for requests                                 |
| `AWS_AWSTATS_SHORTNAME`   | `mybucket`                                                 | yes       | Pretty-print the hostname on AWStats                         |
| `AWS_AWSTATS_HOSTALIASES` | `mybucket.s3.region.amazonaws.com s3.region.amazonaws.com` | no        | Space-separated list of all other possible request Host headers |

#### When executing image to process new logs:

Note that the first time this process is run, you must also specify the 'first run' variables, above

| Name                     | Options / Example | Mandatory | Purpose                                                      |
| ------------------------ | ----------------- | --------- | ------------------------------------------------------------ |
| `AWS_AWSTATS_LOG_BUCKET` | `mylogs`          | yes       | Name of the bucket in which logs will be found               |
| `AWS_AWSTATS_LOG_PREFIX` | `myprefix`        | no        | S3 logs can _optionally_ include a prefix, useful if you're logging requests from more than one bucket in the same place. Set the prefix here if you need to differentiate between logs. |
| `AWS_ACCESS_KEY_ID`      | (secret key ID)   | yes       | Self-explanatory                                             |
| `AWS_SECRET_ACCESS_KEY`  | (secret key)      | yes       | Self-explanatory                                             |

## Example execution

### Building image

:warning: **NOTE**​ Right now I am not sure whether I can distribute the GeoIP databases via this repo. Therefore, I apologise, but there's a bit of a manual process involved in grabbing the GeoIP databases and including them in this project before you can go ahead and build the image :disappointed:

Old way of building the image:

```bash
docker build --build-arg GEOLITE_LICENSE_KEY="_THE_KEY_" -t <tag> .
```

Current way of building the image: download the GeoIP GeoLite2-City and GeoLite2-Country databases and place them in `./GeoIP/`. Update the `Dockerfile` accordingly; then build:

```bash
docker build -t <tag> .
```

### Processing logs

The following example creates a new `awstats.conf` file and processes log files for S3 instance `mybucket` placed in bucket `mylogs` with the logging prefix `myprefix`. The data files are written to a Docker volume that will be auto-created if it doesn't already exist.

```bash
docker run \
    -e AWS_AWSTATS_DRY_RUN="true" \
    -e AWS_AWSTATS_CONFIG="regenerate" \
    -e AWS_AWSTATS_HOSTNAME="mybucket.s3.amazonaws.com" \
    -e AWS_AWSTATS_SHORTNAME="mybucket" \
    -e AWS_AWSTATS_HOSTALIASES="mybucket.s3.region.amazonaws.com s3.region.amazonaws.com" \
    -e AWS_AWSTATS_LOG_BUCKET="mylogs" \
    -e AWS_AWSTATS_LOG_PREFIX="myprefix" \
    -e AWS_ACCESS_KEY_ID="_secret_key_id_" \
    -e AWS_SECRET_ACCESS_KEY="_secret_key_" \
    -v aws-stats-01-input:/var/awstats-input -v aws-stats-01-db:/var/awstats-db <tag>
```

### Serving logs

```bash
docker run -p 8080:80 \
    -v aws-stats-01-input:/var/awstats-input -v aws-stats-01-db:/var/awstats-db <tag> serve
```

