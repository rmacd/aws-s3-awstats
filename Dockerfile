FROM frolvlad/alpine-glibc as base

RUN apk --no-cache add wget perl-app-cpanminus make gcc clang perl-dev libc-dev
RUN apk --no-cache add openssl openssl-dev perl-module-build perl-net-http perl-test-needs \
    perl-path-class perl-list-utilsby perl-http-message perl-encode-locale perl-locale-codes perl-moo \
    perl-devel-stacktrace perl-package-stash-xs perl-package-stash perl-list-someutils \
    perl-list-allutils perl-test-requiresinternet perl-www-robotrules perl-http-cookies \
    perl-http-daemon perl-variable-magic perl-params-validate perl-extutils-depends perl-strictures \
    perl-b-hooks-endofscope perl-cpanel-json-xs perl-namespace-clean perl-namespace-autoclean \
    perl-test-deep perl-eval-closure perl-mro-compat perl-specio perl-html-tagset \
    perl-html-parser perl-http-negotiate perl-file-listing perl-file-sharedir-install perl-datetime \
    perl-libwww perl-io-socket-ssl perl-lwp-protocol-https perl-json-maybexs \
    perl-netaddr-ip perl-netaddr-ip perl-test-number-delta perl-file-which

#COPY cpan-outdated /usr/local/bin
#RUN chmod +x /usr/local/bin/cpan-outdated && /usr/local/bin/cpan-outdated -p | cpanm

RUN cpanm XString Geo::IP::PurePerl Data::Validate::IP GeoIP2::Database::Reader

RUN apk --no-cache del gcc make perl-app-cpanminus clang perl-dev libc-dev libc-utils openssl openssl-dev \
    perl-module-build perl-test-needs perl-test-deep perl-test-number-delta \
    perl-file-which 

#FROM base as populate-geoip
## ARG GEOLITE_LICENSE_KEY
## Add GeoIP - based on openmicroscopy/awstats
#RUN apk --no-cache add curl \
#    && mkdir -p /opt/GeoIP \
#    && curl -G -L "https://download.maxmind.com/app/geoip_download" \
#        -d "edition_id=GeoLite2-Country" \
#        -d "license_key=${GEOLITE_LICENSE_KEY}" \
#        -d "suffix=tar.gz" \
#        | gunzip -c - > /opt/GeoIP/GeoLite2-Country.mmdb \
#    && curl -G -L "https://download.maxmind.com/app/geoip_download" \
#        -d "edition_id=GeoLite2-City" \
#        -d "license_key=${GEOLITE_LICENSE_KEY}" \
#        -d "suffix=tar.gz" \
#        | gunzip -c - > /opt/GeoIP/GeoLite2-City.mmdb

FROM base
#COPY --from=populate-geoip /opt/GeoIP /opt/GeoIP

RUN apk --no-cache add curl \
    && curl -sL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip \
    && unzip awscliv2.zip
RUN /aws/install
RUN rm /awscliv2.zip && rm -rf /aws/dist/awscli/examples

RUN mkdir /opt/GeoIP
COPY ./GeoIP/GeoLite2-City_20200616/GeoLite2-City.mmdb /opt/GeoIP/
COPY ./GeoIP/GeoLite2-Country_20200616/GeoLite2-Country.mmdb /opt/GeoIP/

## install & fix buggy awstats
RUN apk --no-cache add awstats patch
COPY awstats.patch /tmp
RUN patch /usr/lib/awstats/cgi-bin/lib/mime.pm < /tmp/awstats.patch
RUN apk --no-cache del patch

## set up apache & cgi
RUN apk --no-cache add apache2
COPY apache2-awstats.conf /etc/apache2/conf.d/000-awstats.conf
RUN sed -i '/#LoadModule rewrite_module/s/^#//g ; /#LoadModule cgi_module/s/#//g' /etc/apache2/httpd.conf

## now set up awstats
RUN rm /usr/lib/awstats/cgi-bin/awstats.*.conf \
    && rm /etc/awstats/awstats.*.conf \
    && ln -s /etc/awstats/awstats.conf /usr/lib/awstats/cgi-bin/awstats.conf
COPY awstats.template.conf /
COPY docker-entrypoint.sh /usr/local/bin
RUN chmod +x /usr/local/bin/docker-entrypoint.sh && \
    ln -s /usr/local/bin/docker-entrypoint.sh /
COPY run-awstats.sh /usr/local/bin
RUN chmod +x /usr/local/bin/run-awstats.sh && \
    ln -s /usr/local/bin/run-awstats.sh /

ENTRYPOINT ["docker-entrypoint.sh"]
CMD []

EXPOSE 80/tcp
