#!/bin/sh

echo "#!/bin/sh" 
echo "# \\"
echo "exec /usr/bin/expect -- \"\$0\" \${1+\"\$@\"}"
echo ""
echo "exp_version -exit 5.0"
echo ""
echo "set FW_HOST [lindex \$argv 0]"
echo "set FW_PORT [lindex \$argv 1]"
echo "set FW_USERNAME [lindex \$argv 2]"
echo "set FW_PASSWORD [lindex \$argv 3]"
echo ""
echo "spawn ssh -p \$FW_PORT \$FW_USERNAME@\$FW_HOST"
echo ""
echo "expect \"password:\""
echo 'send "$FW_PASSWORD\\r"'
echo "expect \"#\""
echo ""

RULESFILE=$1
while IFS= read -r line
do
	echo "$line" | grep "edit" >/dev/null 2>/dev/null
	if [ $? -eq 0 ] ; then
		line="edit 0"
	fi

	echo -n "send \""
	echo -n "$line"
	echo -n "\\"
	echo -n "r"
	echo "\""
	echo "sleep 1"
	echo "expect \"#\""
	echo "sleep 1"
done < "$RULESFILE"

echo -n "send \"quit "
echo -n "\\"
echo "r\""
