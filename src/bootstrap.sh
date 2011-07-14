#!/bin/bash
function extract()
{
	SKIP=`awk '/^__TARFILE_FOLLOWS__/ { print NR + 1; exit 0; }' $0`

	#remember our file name
	THIS=`pwd`/$0
	tmp=$(mktemp -d /tmp/bootstrap.XXXXX)

	# take the tarfile and pipe it into tar
	echo "decompressing to $tmp"
	cd $tmp
	tail -n +$SKIP $THIS | tar -xz
	export EC2_GIT_BOOTSTRAP_PATH=$tmp/data
	chmod -R a+Xr $tmp
	./post-extract.sh
}

set -x
log=/var/log/ec2-git-bootstrap.log
extract > $log
echo "EC2-GIT-BOOTSTRAP: Completed!" >> $log 

#
# place any bash script here you need.
# Any script here will happen after the tar file extract.
echo "Finished"
exit 0

# NOTE: Don't place any newline characters after the last line below.
__TARFILE_FOLLOWS__
