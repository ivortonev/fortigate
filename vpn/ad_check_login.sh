#!/bin/bash

. ./conf.cfg
. ./variaveis.cfg

$CMD_LDAPSEARCH -H ldap://$AD_HOST -w $AD_PASSWD -b $AD_BASEDN -D $AD_LOGIN sAMAccountName=$1 | $CMD_GREP ^sAMAccountName | $CMD_CUT -f 2 -d " "
