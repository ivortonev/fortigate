#!/bin/bash

for i in `/usr/bin/grep ^CMD variaveis.cfg  | /usr/bin/cut -f 2 -d "\""` ; do
	if [ -f $i ] ; then
		echo "$i ok"
	else
		echo "O comando $i nao foi encontrado. Ele e necessario como"
		echo "dependencia dos scripts da renovacao/ criacao de VPN."
		echo "Edite o arquivo variaveis.cfg para ajustar ou"
		echo "instale o pacote que contem o executavel"
		echo ""
	fi
done

chmod 755 *sh
chmod 755 *exp
chmod 600 *cfg
