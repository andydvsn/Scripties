#!/bin/bash

## mediawikiupdater.sh v1.00 (15th Feb 2018) by Andy Davison
##  Updates mediawiki automatically just using the URL of the new version.


PHPVER="php-7.0"


if [[ $# == 0 ]]; then
	echo "Usage $0: <URL>"
	exit 1
fi

if [[ ! -h ./wiki ]]; then
	echo "Please run me from web root, where the 'wiki' symlink lives."
	exit 1
fi

CURRENTVER=`readlink wiki`
UPDATINTGZ=${1##*/}
UPDATINVER=${UPDATINTGZ%.tar*}
UPDATINVSH=${UPDATINVER##*-}

if [ ${#CURRENTVER} != ${#UPDATINVER} ]; then
	echo "Something has gone wrong. Please make sure you have pointed to the .tar.gz download."
	echo "Current Version Detected: $CURRENTVER"
	echo "Update Version Detected:  $UPDATINVER"
	exit 1
fi

WIKIDBSRVR=`cat $CURRENTVER/LocalSettings.php | grep wgDBserver | cut -d'"' -f 2`
WIKIDBNAME=`cat $CURRENTVER/LocalSettings.php | grep wgDBname | cut -d'"' -f 2`
WIKIDBUSER=`cat $CURRENTVER/LocalSettings.php | grep wgDBuser | cut -d'"' -f 2`
WIKIDBPASS=`cat $CURRENTVER/LocalSettings.php | grep wgDBpassword | cut -d'"' -f 2`
BACKUPDATE=$(TZ=Europe/London date +%Y%m%d%H%M)

if [ ! -d $UPDATINVER ]; then

	echo
	echo "Upgrading from $CURRENTVER to $UPDATINVER."
	echo

	echo -n "Beginning backup of $CURRENTVER..."
	mkdir -p ../backups/$BACKUPDATE-$CURRENTVER
	mysqldump --host=$WIKIDBSRVR --user=$WIKIDBUSER --password=$WIKIDBPASS $WIKIDBNAME > ../backups/$BACKUPDATE-$CURRENTVER/$WIKIDBNAME.sql
	mysqldump --host=$WIKIDBSRVR --user=$WIKIDBUSER --password=$WIKIDBPASS $WIKIDBNAME --xml > ../backups/$BACKUPDATE-$CURRENTVER/$WIKIDBNAME.xml
	cp -R $CURRENTVER ../backups/$BACKUPDATE-$CURRENTVER/
	cp .htaccess ../backups/$BACKUPDATE-$CURRENTVER/root_htaccess
	echo " compressing..."
	tar czf ../backups/$BACKUPDATE-$CURRENTVER.tgz ../backups/$BACKUPDATE-$CURRENTVER
	rm -rf ../backups/$BACKUPDATE-$CURRENTVER
	echo " done."

	echo -n "Downloading $UPDATINTGZ..."
	wget -q $1
	echo -n " decompressing..."
	tar -xzf $UPDATINTGZ
	rm -rf $UPDATINTGZ $UPDATINVER/images

	if [ -d $UPDATINVER ]; then
		echo " done."
	else
		echo " failed."
		echo
		echo "Couldn't find '$UPDATINVER' directory containing the new MediaWiki installation. Aborting."
		exit 1
	fi

	echo -n "Moving content and configuration..."
	mv $CURRENTVER/images $UPDATINVER/
	mv $CURRENTVER/LocalSettings.php $UPDATINVER/
	echo " done."

	EXTSTOFIX=`diff $CURRENTVER/extensions $UPDATINVER/extensions | grep "Only in $CURRENTVER" | cut -d ':' -f 2 | xargs`
	if [[ "$EXTSTOFIX" != "" ]]; then
		echo
		echo "The following extensions were present in $CURRENTVER, but not in the vanilla $UPDATINVER."
		echo
		echo "  $EXTSTOFIX"
		echo
		echo "They will be copied to $UPDATINVER/extensions but you MUST check for compatibility updates."
		echo
		for e in $EXTSTOFIX ; do
			cp -R $CURRENTVER/extensions/$e $UPDATINVER/extensions/
		done
	fi

	SKINSTOFIX=`diff $CURRENTVER/skins $UPDATINVER/skins | grep "Only in $CURRENTVER" | cut -d ':' -f 2 | xargs`
	if [[ "$SKINSTOFIX" != "" ]]; then
		echo
		echo "The following skins were present in $CURRENTVER, but not in the vanilla $UPDATINVER."
		echo
		echo "  $SKINSTOFIX"
		echo
		echo "They will be copied to $UPDATINVER/skins but you MUST check for compatibility updates."
		echo
		for e in $SKINSTOFIX ; do
			cp -R $CURRENTVER/skins/$e $UPDATINVER/skins/
		done
	fi

else

	echo
	echo "WARNING! There is already a '$UPDATINVER' directory. No changes to it have been made."
	
fi

echo
echo "Check the following documentation for any required manual fixes:"
echo
echo "  https://www.mediawiki.org/wiki/Manual:Upgrading"
echo
read -n 1 -s -r -p "Once reviewed, press any key to upgrade the database and make '$UPDATINVER' live..."
echo " enabling..."
echo

$PHPVER $UPDATINVER/maintenance/update.php

if [ ! $? = "0" ]; then
	echo "Looks like there was an error with the upgrade script."
	echo
	echo "This script is running with $PHPVER. Check this matches the website and is configured correctly."
	echo
	exit 1
fi

rm wiki
ln -s $UPDATINVER wiki

echo
echo "To confirm site operation and version, visit:"
echo
echo "  http://${PWD##*/}/w/Special:Version"
echo
echo "MediaWiki upgraded to v$UPDATINVSH."
echo

exit 0













