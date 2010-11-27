#!/bin/bash
nohup rails runner app/collector/collector_daemon.rb $1 &