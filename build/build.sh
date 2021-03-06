#!/bin/bash -ex

BUILDID=$1
BRANCH=$2
LAYERS=$3
OVERRIDES=$4

function setup_oe() {

OIFS=$IFS
IFS=','
if [[ ! $OVERRIDES == "None" ]];
then
	for pair in $OVERRIDES;
	do
		REPO_NAME=`echo $pair | cut -f 1 -d ':'`
		REPO_GIT=`echo $pair | cut -f 2 -d ':'`
		if [[ $REPO_NAME == "xenclient-oe" ]];
		then
			echo "Overrwriting for xenclient-oe"
cat <<EOF >> build/local.settings
META_SELINUX_REPO=file:///home/build/builder/build/git/meta-selinux.git
EXTRA_REPO=file:///home/build/builder/build/git/xenclient-oe-extra.git
EXTRA_DIR=extra
EXTRA_TAG="master"
XENCLIENT_REPO=git://$REPO_GIT/xenclient-oe.git
XENCLIENT_TAG="master"
EOF
		fi
	done
fi
IFS=$OIFS
}


function setup_oxt() {

OIFS=$IFS
IFS=','

if [[ ! $OVERRIDES == "None" ]];
then
	for pair in $OVERRIDES;
	do
		REPO_NAME=`echo $pair | cut -f 1 -d ':'`
		REPO_GIT=`echo $pair | cut -f 2 -d ':'`
		if [[ $REPO_NAME == "openxt" ]];
		then
			git clone git://$REPO_GIT/openxt.git
		fi
	done
fi
if [ ! -d "openxt" ];
then
	git clone file:///home/build/builder/build/git/openxt.git
fi
IFS=$OIFS

}

umask 0022
cd build
#Extra case for openxt override
setup_oxt
cd openxt
git checkout $BRANCH
cp -r ../../certs .
mv /tmp/git_heads_$BUILDID git_heads
cp example-config .config
cat <<EOF >> .config
NAME_SITE="ext"
OPENXT_GIT_MIRROR="/home/build/builder/build/git"
OPENXT_GIT_PROTOCOL="file"
REPO_PROD_CACERT="/home/build/builder/build/certs/prod-cacert.pem"
REPO_DEV_CACERT="/home/build/builder/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_CERT="/home/build/builder/build/certs/dev-cacert.pem"
REPO_DEV_SIGNING_KEY="/home/build/builder/build/certs/dev-cakey.pem"
WIN_BUILD_OUTPUT="buildbot@192.168.0.10:/home/build/win"
SYNC_CACHE_OE=192.168.0.10:/home/build/oe
BUILD_RSYNC_DESTINATION=127.0.0.1:/home/storage/builds
#NETBOOT_HTTP_URL="Replace me"
BRANCH=$BRANCH
EOF
setup_oe
./do_build.sh -i $BUILDID -s setupoe,sync_cache
if [[ $LAYERS != 'None' ]];
then
	../../engage_layers.sh $LAYERS
fi
../../engage_srcrevs.sh $BRANCH $OVERRIDES
./do_build.sh -i $BUILDID | tee build.log
ret=${PIPESTATUS[0]}
cd -
cd -

exit $ret
