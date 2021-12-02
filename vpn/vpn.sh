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

# Date check
#DATE_END_TIMESTAMP=`$CMD_DATE -d $DATE_D/$DATE_M/$DATE_Y 23:59:59 +%s`
#if [ $DATE_END_TIMESTAMP -gt $DEF_DATE_END_TIMESTAMP ] ; then
#	$CMD_ECHO "A data final informada excede"; 
#	$CMD_ECHO "o maximo permitido - 100 dias";
#	exit 4;
# end date check

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

./$SCRIPT_CFG_GET_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/userlocal
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando conta local do firewall ... "
	FW_VPN_USER_LOCAL=`$CMD_CAT $TMP_DIR/userlocal | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_USER_LOCAL ] ; then
		$CMD_ECHO "!!! ATENCAO !!! A VPN desse usuario nao existe. Sera necessario colocar o usuario na lista de usuarios de VPN e criar a regra de firewall Executando criacao do objeto de usuario: $VPN_USERNAME "
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_USERLOCAL $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME
		MAIL_01="0"
	else
		$CMD_ECHO "Conta local encontrada : $FW_VPN_USER_LOCAL"
		$CMD_ECHO ""
		MAIL_01="1"
	fi


./$SCRIPT_CFG_GET_SCHEDULE_NAME $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $VPN_USERNAME >> $TMP_DIR/schedule
	STEP=$(($STEP+1))
	$CMD_ECHO -n "[$STEP]Verificando schedule de VPN ... "
	FW_VPN_SCHEDULE_NAME=`$CMD_CAT $TMP_DIR/schedule | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_SCHEDULE_NAME ] ; then
		$CMD_ECHO "Executando criacao do objeto de schedule: $FW_VPN_SCHEDULE_NAME_DEFAULT"
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_SCHEDULE_DATE  $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_SCHEDULE_NAME_DEFAULT $DEF_DATE_START $DATE_END_VPN
		MAIL_02="0"
	else
		$CMD_ECHO "Nome do schedule encontrado : $FW_VPN_SCHEDULE_NAME"
		$CMD_ECHO ""
		MAIL_02="1"
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
	FW_VPN_ADDRESS_NAME=`$CMD_CAT $TMP_DIR/address_name | $CMD_GREP edit | $CMD_CUT -f 2 -d "\"" | $CMD_TAIL -n 1 | $CMD_HEAD -n 1`
	if [ -z $FW_VPN_ADDRESS_NAME ] ; then
		$CMD_ECHO "Executando criacao do objeto de host: $FW_VPN_ADDRESS_NAME_DEFAULT"
		$CMD_ECHO ""
		./$SCRIPT_CFG_EDIT_ADDRESS_IP $FW_HOST $FW_PORT $FW_USERNAME $FW_PASSWORD $FW_VPN_ADDRESS_NAME_DEFAULT $WKS_IP 
		MAIL_03="0"
	else
		$CMD_ECHO "Nome do objeto de estacao encontrado: $FW_VPN_ADDRESS_NAME"
		$CMD_ECHO ""
		MAIL_03="1"
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

if [ $MAIL_01 -eq 1 ] && [ $MAIL_02 -eq 1 ] && [ $MAIL_03 -eq 1 ] ; then
	MAIL_TMP=`$CMD_MKTEMP`
	$CMD_ECHO "Prezado/a, a sua conexao de VPN foi renovada." >> $MAIL_TMP
	$CMD_ECHO " " >> $MAIL_TMP
	$CMD_ECHO "Lembrando que o login e case sensitive, portanto se o seu login tenha letras maiusculas o mesmo deve ser informado com as letras na caixa correspondente:" >> $MAIL_TMP
	$CMD_ECHO " " >> $MAIL_TMP
	$CMD_ECHO "Usuario: $FW_VPN_USER_LOCAL" >> $MAIL_TMP
	$CMD_ECHO "Senha: a senha de login na estacao de trabalho do MEC " >> $MAIL_TMP
	$CMD_ECHO "IP da estação de trabalho para realizar o acesso remoto: $WKS_IP " >> $MAIL_TMP
	$CMD_ECHO "Vencimento: $DATE_END 23:59 " >> $MAIL_TMP
	$CMD_ECHO " " >> $MAIL_TMP
	$CMD_ECHO "No cliente de VPN Forticlient no campo de usuario e necessario informar apenas o login de usuario." >> $MAIL_TMP
        $CMD_ECHO "No cliente de acesso a area de trabalho remota no campo de usuario e necessário acrescentar \"mec\" no nome do usuario, ficando \"mec\login\". " >> $MAIL_TMP
	$CMD_ECHO " " >> $MAIL_TMP
	$CMD_ECHO " " >> $MAIL_TMP
	$CMD_ECHO "------- " >> $MAIL_TMP
	$CMD_ECHO "cseg@mec.gov.br" >> $MAIL_TMP
	$CMD_MAIL $MAIL_ADDR,$RCPTMAIL -s "Renovacao de acesso VPN" < $MAIL_TMP
	$CMD_RM -f $MAIL_TMP
fi

$CMD_RM -rf $TMP_DIR
