#!/bin/sh

awstats.pl -update -config=awstats.conf -LogFile="/usr/bin/logresolvemerge.pl addfolder=/var/awstats-input/new |" -showdropped
