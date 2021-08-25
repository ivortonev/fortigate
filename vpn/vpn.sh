#!/bin/bash

. ./conf.cfg
. ./variaveis.cfg

# O nome de usuario no AD pode ser ate 20 caracteres
AD_USERNAME=`$CMD_ECHO $1 | $CMD_TR [A-Z] [a-z] | $CMD_CUT -c 1-$MAX_CHARS`

# Verificacao da data final
#if [ $2 != "^[0-9]{4}/[0-9]{2}/[0-9]{2}$" ] ; then
if [ $2 == "^202[1-9]/[0-3][0-9]/[0-9][0-9]$" ] ; then
	$CMD_ECHO "Formato de data invalida. Informe ANO/MES/DIA"
	exit 4
fi

DATE_END=$2
WKS_IP=$3
STEP=0

# IP check
IP_TEST=`$CMD_ECHO $WKS_IP| $CMD_GREP -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}'`
if [ -z $IP_TEST ] ; then
	$CMD_ECHO "O IP informado esta incorreto";
	$CMD_ECHO "infome a sequencia \"login data ip\"";
	exit 4;
fi
# end IP Check

# Date check

if [ "$DATE_END" != "^[0-9]{4}/[0-9]{2}/[0-9]{2}$" ] ; then
	$CMD_ECHO "A data informada esta incorreta";
	$CMD_ECHO "infome a sequencia \"login data ip\"";
	exit 5;
fi
VRF_ANO=`$CMD_ECHO $DATE_END | $CMD_CUT -f 1 -d "/"`
VRF_MES=`$CMD_ECHO $DATE_END | $CMD_CUT -f 2 -d "/"`
VRF_DIA=`$CMD_ECHO $DATE_END | $CMD_CUT -f 3 -d "/"`
MAX_ANO=`$CMD_ECHO $DEF_DATE_END | $CMD_CUT -f 1 -d "/"`
MAX_MES=`$CMD_ECHO $DEF_DATE_END | $CMD_CUT -f 2 -d "/"`
MAX_DIA=`$CMD_ECHO $DEF_DATE_END | $CMD_CUT -f 3 -d "/"`

if [ $VRF_ANO -gt $MAX_ANO ] ; then
	echo "Data final incorreta - ano"
	exit 3
fi

if [ $VRF_MES -gt $MAX_MES ] ; then
	echo "Data final incorreta - mes"
	exit 3
fi

# End date check

TMP_DIR=`$CMD_MKTEMP -d`
readonly TMP_DIR

$CMD_ECHO ""
STEP=$(($STEP+1))
$CMD_ECHO -n "[$STEP]Verificando conta no AD ... "
VPN_USERNAME=`./$SCRIPT_AD_CHECK_LOGIN $AD_USERNAME`
if [ -z $VPN_USERNAME ] ; then
	$CMD_ECHO "Conta nao encontrada"
	$CMD_ECHO "Verifique se o login esta correto e tente novamente"
	exit 1
else
	$CMD_ECHO "Conta encontrada no AD: $VPN_USERNAME"
	$CMD_ECHO ""
fi

FW_VPN_SCHEDULE_NAME_DEFAULT="vpn_$VPN_USERNAME"
FW_VPN_ADDRESS_NAME_DEFAULT="wks_$VPN_USERNAME"

./$SCRIPT_CFG_GET_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/userlocal
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando conta local do firewall ... "
	FW_VPN_USER_LOCAL=`$CMD_CAT $TMP_DIR/userlocal | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_USER_LOCAL ] ; then
		$CMD_ECHO "!!! ATENCAO !!! A VPN desse usuario nao existe. Sera necessario colocar o usuario na lista de usuarios de VPN e criar a regra de firewall Executando criacao do objeto de usuario: $VPN_USERNAME "
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME

	else
		$CMD_ECHO "Conta local encontrada : $FW_VPN_USER_LOCAL"
		$CMD_ECHO ""
	fi


./$SCRIPT_CFG_GET_SCHEDULE_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/schedule
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando schedule de VPN ... "
	FW_VPN_SCHEDULE_NAME=`$CMD_CAT $TMP_DIR/schedule | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_SCHEDULE_NAME ] ; then
		$CMD_ECHO "Executando criacao do objeto de schedule: $FW_VPN_SCHEDULE_NAME_DEFAULT"
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_SCHEDULE_DATE  $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME_DEFAULT $DEF_DATE_START $DATE_END

	else
		$CMD_ECHO "Nome do schedule encontrado : $FW_VPN_SCHEDULE_NAME"
		$CMD_ECHO ""
		if [ $FW_VPN_SCHEDULE_NAME != $FW_VPN_SCHEDULE_NAME_DEFAULT ] ; then
			STEP=$(($STEP+1))
			$CMD_ECHO "[$STEP]Nome do objeto de schedule diferente do padrao. Renomeando para $FW_VPN_SCHEDULE_NAME_DEFAULT"
		$CMD_ECHO ""
			./$SCRIPT_CFG_EDIT_SCHEDULE_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME $FW_VPN_SCHEDULE_NAME_DEFAULT
		fi
		STEP=$(($STEP+1))
		$CMD_ECHO -n "[$STEP]Verificando data final da VPN ... "
		./$SCRIPT_CFG_GET_SCHEDULE_EXTENDED $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME_DEFAULT >> $TMP_DIR/schedule_extended
		SCHEDULE_DATE_END=`$CMD_CAT $TMP_DIR/schedule_extended | $CMD_GREP "set end" | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1 | $CMD_CUT -f 2 -d ":" | $CMD_CUT -f 2 -d " " | $CMD_TR -d '[:cntrl:]' `
		if [ "$SCHEDULE_DATE_END" != "$DATE_END" ] ; then
			$CMD_ECHO "Alterando a data final da VPN para $VRF_DIA/$VRF_MES/$VRF_ANO"
			$CMD_ECHO ""
			./$SCRIPT_CFG_EDIT_SCHEDULE_DATE  $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME_DEFAULT $DEF_DATE_START $DATE_END
		else
			$CMD_ECHO "Data final $VRF_DIA/$VRF_MES/$VRF_ANO"
			$CMD_ECHO ""
		fi
	fi
		

./$SCRIPT_CFG_GET_ADDRESS_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/address_name
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando objeto de estacao ... "
	FW_VPN_ADDRESS_NAME=`$CMD_CAT $TMP_DIR/address_name | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_ADDRESS_NAME ] ; then
		$CMD_ECHO "Executando criacao do objeto de host: $FW_VPN_ADDRESS_NAME_DEFAULT"
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_ADDRESS_IP $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_ADDRESS_NAME_DEFAULT $WKS_IP 
	else
		$CMD_ECHO "Nome do objeto de estacao encontrado: $FW_VPN_ADDRESS_NAME"
		$CMD_ECHO ""
		if [ $FW_VPN_ADDRESS_NAME != $FW_VPN_ADDRESS_NAME_DEFAULT ] ; then
			STEP=$(($STEP+1))
			$CMD_ECHO "[$STEP]Nome do objeto de objeto de estacao diferente do padrao. Renomeando para $FW_VPN_ADDRESS_NAME_DEFAULT"
			./$SCRIPT_CFG_EDIT_ADDRESS_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_ADDRESS_NAME $FW_VPN_ADDRESS_NAME_DEFAULT
			$CMD_ECHO ""
		fi
		STEP=$(($STEP+1))
		$CMD_ECHO -n "[$STEP]Verificando o ip da estacao de trabalho ... "
		./$SCRIPT_CFG_GET_ADDRESS_EXTENDED $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_ADDRESS_NAME_DEFAULT >> $TMP_DIR/address_extended
		ADDRESS_IP=`$CMD_CAT $TMP_DIR/address_extended | $CMD_GREP "set subnet" | $CMD_CUT -c 10- | $CMD_CUT -f 3 -d " " | $CMD_TAIL -n 1 | $CMD_HEAD -n 1 | $CMD_TR -d '[:cntrl:]' `
		if [ $WKS_IP != $ADDRESS_IP ] ; then
			$CMD_ECHO "Alterando o IP da estacao de trabalho para $WKS_IP"
			./$SCRIPT_CFG_EDIT_ADDRESS_IP $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_ADDRESS_NAME_DEFAULT $WKS_IP 
		else
			$CMD_ECHO "IP da estacao de trabalho: $WKS_IP"
			$CMD_ECHO ""
		fi
	fi


$CMD_RM -rf $TMP_DIR
