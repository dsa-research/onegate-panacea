#!/bin/bash

# -------------------------------------------------------------------------- #
# Copyright 2002-2014, OpenNebula Project (OpenNebula.org), C12G Labs        #
#                                                                            #
# Licensed under the Apache License, Version 2.0 (the "License"); you may    #
# not use this file except in compliance with the License. You may obtain    #
# a copy of the License at                                                   #
#                                                                            #
# http://www.apache.org/licenses/LICENSE-2.0                                 #
#                                                                            #
# Unless required by applicable law or agreed to in writing, software        #
# distributed under the License is distributed on an "AS IS" BASIS,          #
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.   #
# See the License for the specific language governing permissions and        #
# limitations under the License.                                             #
#--------------------------------------------------------------------------- #

#-------------------------------------------------------------------------------
# Install program for OpenNebula. It will install it relative to
# $ONE_LOCATION if defined with the -d option, otherwise it'll be installed
# under /. In this case you may specified the oneadmin user/group, so you do
# not need run the OpenNebula daemon with root privileges
#-------------------------------------------------------------------------------

#-------------------------------------------------------------------------------
# COMMAND LINE PARSING
#-------------------------------------------------------------------------------
usage() {
 echo
 echo "Usage: install.sh [-u install_user] [-g install_group] [-k keep conf]"
 echo "                  [-d ONE_LOCATION] [-c cli|ec2] [-r] [-h]"
 echo
 echo "-u: user that will run opennebula, defaults to user executing install.sh"
 echo "-g: group of the user that will run opennebula, defaults to user"
 echo "    executing install.sh"
 echo "-k: keep configuration files of existing OpenNebula installation, useful"
 echo "    when upgrading. This flag should not be set when installing"
 echo "    OpenNebula for the first time"
 echo "-d: target installation directory, if not defined it'd be root. Must be"
 echo "    an absolute path."
 echo "-r: remove Opennebula, only useful if -d was not specified, otherwise"
 echo "    rm -rf \$ONE_LOCATION would do the job"
 echo "-l: creates symlinks instead of copying files, useful for development"
 echo "-h: prints this help"
}
#-------------------------------------------------------------------------------

PARAMETERS="hkrlcsou:g:d:"

if [ $(getopt --version | tr -d " ") = "--" ]; then
    TEMP_OPT=`getopt $PARAMETERS "$@"`
else
    TEMP_OPT=`getopt -o $PARAMETERS -n 'install.sh' -- "$@"`
fi

if [ $? != 0 ] ; then
    usage
    exit 1
fi

eval set -- "$TEMP_OPT"

INSTALL_ETC="yes"
UNINSTALL="no"
LINK="no"
ONEADMIN_USER=`id -u`
ONEADMIN_GROUP=`id -g`
SRC_DIR=$PWD

while true ; do
    case "$1" in
        -h) usage; exit 0;;
        -k) INSTALL_ETC="no"   ; shift ;;
        -r) UNINSTALL="yes"   ; shift ;;
        -l) LINK="yes" ; shift ;;
        -u) ONEADMIN_USER="$2" ; shift 2;;
        -g) ONEADMIN_GROUP="$2"; shift 2;;
        -d) ROOT="$2" ; shift 2 ;;
        --) shift ; break ;;
        *)  usage; exit 1 ;;
    esac
done

#-------------------------------------------------------------------------------
# Definition of locations
#-------------------------------------------------------------------------------

CONF_LOCATION="$HOME/.one"

if [ -z "$ROOT" ] ; then
    BIN_LOCATION="/usr/bin"
    LIB_LOCATION="/usr/lib/one"
    ETC_LOCATION="/etc/one"
    LOG_LOCATION="/var/log/one"
    VAR_LOCATION="/var/lib/one"
    ONEGATE_LOCATION="$LIB_LOCATION/onegate"
    SUNSTONE_LOCATION="$LIB_LOCATION/sunstone"
    ONEFLOW_LOCATION="$LIB_LOCATION/oneflow"
    SYSTEM_DS_LOCATION="$VAR_LOCATION/datastores/0"
    DEFAULT_DS_LOCATION="$VAR_LOCATION/datastores/1"
    RUN_LOCATION="/var/run/one"
    LOCK_LOCATION="/var/lock/one"
    INCLUDE_LOCATION="/usr/include"
    SHARE_LOCATION="/usr/share/one"
    MAN_LOCATION="/usr/share/man/man1"
    VM_LOCATION="/var/lib/one/vms"

    MAKE_DIRS="$BIN_LOCATION $LIB_LOCATION $VAR_LOCATION \
               $ONEGATE_LOCATION $ETC_LOCATION"

    DELETE_DIRS="$ONEGATE_LOCATION"

    CHOWN_DIRS=""

else
    BIN_LOCATION="$ROOT/bin"
    LIB_LOCATION="$ROOT/lib"
    ETC_LOCATION="$ROOT/etc"
    VAR_LOCATION="$ROOT/var"
    ONEGATE_LOCATION="$LIB_LOCATION/onegate"
    SUNSTONE_LOCATION="$LIB_LOCATION/sunstone"
    ONEFLOW_LOCATION="$LIB_LOCATION/oneflow"
    SYSTEM_DS_LOCATION="$VAR_LOCATION/datastores/0"
    DEFAULT_DS_LOCATION="$VAR_LOCATION/datastores/1"
    INCLUDE_LOCATION="$ROOT/include"
    SHARE_LOCATION="$ROOT/share"
    MAN_LOCATION="$ROOT/share/man/man1"
    VM_LOCATION="$VAR_LOCATION/vms"

    MAKE_DIRS="$BIN_LOCATION $LIB_LOCATION $VAR_LOCATION \
               $ONEGATE_LOCATION $ETC_LOCATION"

    DELETE_DIRS="$ONEGATE_LOCATION"

    CHOWN_DIRS="$ROOT"
fi

LIB_DIRS="$LIB_LOCATION/ruby"


#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------
# FILE DEFINITION, WHAT IS GOING TO BE INSTALLED AND WHERE
#-------------------------------------------------------------------------------
#-------------------------------------------------------------------------------

INSTALL_ONEGATE_FILES=(
    ONEGATE_FILES:$ONEGATE_LOCATION
    ONEGATE_BIN_FILES:$BIN_LOCATION
)

INSTALL_ONEGATE_ETC_FILES=(
    ONEGATE_ETC_FILES:$ETC_LOCATION
)


#-----------------------------------------------------------------------------
# OneGate files
#-----------------------------------------------------------------------------

ONEGATE_FILES="src/onegate/onegate-server.rb \
                src/onegate/config.ru"

ONEGATE_BIN_FILES="src/onegate/bin/onegate-server"

ONEGATE_ETC_FILES="src/onegate/etc/onegate-server.conf"


#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------
# INSTALL.SH SCRIPT
#-----------------------------------------------------------------------------
#-----------------------------------------------------------------------------

# --- Create OpenNebula directories ---

if [ "$UNINSTALL" = "no" ] ; then
    for d in $MAKE_DIRS; do
        mkdir -p $DESTDIR$d
    done
fi

# --- Install/Uninstall files ---

do_file() {
    if [ "$UNINSTALL" = "yes" ]; then
        rm $DESTDIR$2/`basename $1`
    else
        if [ "$LINK" = "yes" ]; then
            ln -s $SRC_DIR/$1 $DESTDIR$2
        else
            cp $SRC_DIR/$1 $DESTDIR$2
        fi
    fi
}

INSTALL_SET="${INSTALL_ONEGATE_FILES[@]}"

for i in ${INSTALL_SET[@]}; do
    SRC=$`echo $i | cut -d: -f1`
    DST=`echo $i | cut -d: -f2`

    eval SRC_FILES=$SRC

    for f in $SRC_FILES; do
        do_file $f $DST
    done
done

if [ "$INSTALL_ETC" = "yes" ] ; then
    INSTALL_ETC_SET="${INSTALL_ONEGATE_ETC_FILES[@]}"

    for i in ${INSTALL_ETC_SET[@]}; do
        SRC=$`echo $i | cut -d: -f1`
        DST=`echo $i | cut -d: -f2`

        eval SRC_FILES=$SRC

        OLD_LINK=$LINK
        LINK="no"

        for f in $SRC_FILES; do
            do_file $f $DST
        done

        LINK=$OLD_LINK
   done
fi

# --- Set ownership or remove OpenNebula directories ---

if [ "$UNINSTALL" = "no" ] ; then
    for d in $CHOWN_DIRS; do
        chown -R $ONEADMIN_USER:$ONEADMIN_GROUP $DESTDIR$d
    done
else
    for d in `echo $DELETE_DIRS | awk '{for (i=NF;i>=1;i--) printf $i" "}'`; do
        rmdir $d
    done
fi
