#!/bin/bash
set -x
apt-get -y install git
export GIT_SSH=./git-ssh-wrap.sh
repo=$(mktemp -d /tmp/git-bootstrap.XXXXX)
git clone $(cat data/bootstrap-repo) $repo
cd $repo
./run
