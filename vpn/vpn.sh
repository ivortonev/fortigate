#!/bin/bash

. ./conf.cfg
. ./variaveis.cfg

# O nome de usuario no AD pode ser ate 20 caracteres
AD_USERNAME=`$CMD_ECHO $1 | $CMD_TR [A-Z] [a-z] | $CMD_CUT -c 1-$MAX_CHARS`

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

DATE_Y=`$CMD_ECHO $DATE_END | $CMD_CUT -f 3 -d "/"`
DATE_M=`$CMD_ECHO $DATE_END | $CMD_CUT -f 2 -d "/"`
DATE_D=`$CMD_ECHO $DATE_END | $CMD_CUT -f 1 -d "/"`

DATE_END_VPN="$DATE_Y/$DATE_M/$DATE_D"

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
	MAIL_ADDR=`./$SCRIPT_AD_GET_EMAIL $AD_USERNAME`
	$CMD_ECHO "Conta encontrada no AD: $VPN_USERNAME - $MAIL_ADDR"
	$CMD_ECHO ""
fi

FW_VPN_SCHEDULE_NAME_DEFAULT="vpn_$VPN_USERNAME"
FW_VPN_ADDRESS_NAME_DEFAULT="wks_$VPN_USERNAME"

MAIL_TMP=`$CMD_MKTEMP`

./$SCRIPT_CFG_GET_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/userlocal
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando conta local do firewall ... "
	FW_VPN_USER_LOCAL=`$CMD_CAT $TMP_DIR/userlocal | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_USER_LOCAL ] ; then
		$CMD_ECHO "!!! ATENCAO !!! A VPN desse usuario nao existe. Sera criar a regra de firewall Executando criacao do objeto de usuario: $VPN_USERNAME e acrescentando no mapeamento de usuarios"
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME
		./$SCRIPT_CFG_ADD_MAPPING_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME
		$CMD_ECHO "Prezado/a, a sua conexao de VPN foi criada." >> $MAIL_TMP
	else
		$CMD_ECHO "Conta local encontrada : $VPN_USERNAME"
		$CMD_ECHO ""
	fi


./$SCRIPT_CFG_GET_SCHEDULE_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/schedule
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando schedule de VPN ... "
	FW_VPN_SCHEDULE_NAME=`$CMD_CAT $TMP_DIR/schedule | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_SCHEDULE_NAME ] ; then
		$CMD_ECHO "Executando criacao do objeto de schedule: $FW_VPN_SCHEDULE_NAME_DEFAULT"
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_SCHEDULE_DATE  $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME_DEFAULT $DEF_DATE_START $DATE_END_VPN
	else
		$CMD_ECHO "Prezado/a, a sua conexao de VPN foi renovada." >> $MAIL_TMP
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
		if [ "$SCHEDULE_DATE_END" != "$DATE_END_VPN" ] ; then
			$CMD_ECHO "Alterando a data final da VPN para $DATE_END"
			$CMD_ECHO ""
			./$SCRIPT_CFG_EDIT_SCHEDULE_DATE  $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME_DEFAULT $DEF_DATE_START $DATE_END_VPN
		else
			$CMD_ECHO "Data final $DATE_END"
			$CMD_ECHO ""
		fi
	fi
		

./$SCRIPT_CFG_GET_ADDRESS_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/address_name
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando objeto de estacao ... "
	FW_VPN_ADDRESS_NAME=`$CMD_CAT $TMP_DIR/address_name | $CMD_GREP -i -v vpn | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
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

$CMD_ECHO " " >> $MAIL_TMP
$CMD_ECHO "Lembrando que o login e case sensitive, portanto se o seu login tenha letras maiusculas o mesmo deve ser informado com as letras na caixa correspondente:" >> $MAIL_TMP
$CMD_ECHO " " >> $MAIL_TMP
#$CMD_ECHO "Usuario: $FW_VPN_USER_LOCAL" >> $MAIL_TMP
$CMD_ECHO "Usuario: $VPN_USERNAME" >> $MAIL_TMP
$CMD_ECHO "Senha: a senha de login na estacao de trabalho " >> $MAIL_TMP
$CMD_ECHO "IP da estação de trabalho para realizar o acesso remoto: $WKS_IP " >> $MAIL_TMP
$CMD_ECHO "Vencimento: $DATE_END 23:59 " >> $MAIL_TMP
$CMD_ECHO " " >> $MAIL_TMP
$CMD_ECHO "No cliente de VPN Forticlient no campo de usuario e necessario informar apenas o login de usuario." >> $MAIL_TMP
$CMD_ECHO " " >> $MAIL_TMP
$CMD_ECHO "O cliente de VPN para estacoes Windows pode ser baixado de https://links.fortinet.com/forticlient/win/vpnagent" >> $MAIL_TMP
$CMD_ECHO " " >> $MAIL_TMP
$CMD_ECHO "O cliente de VPN para estacoes Mac pode ser baixado de https://links.fortinet.com/forticlient/mac/vpnagent" >> $MAIL_TMP
$CMD_ECHO " " >> $MAIL_TMP
$CMD_MAIL $MAIL_ADDR,$RCPTMAIL -s "Acesso VPN" < $MAIL_TMP
$CMD_RM -f $MAIL_TMP

$CMD_RM -rf $TMP_DIR
