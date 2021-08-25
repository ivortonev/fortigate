# fortigate vpn
<pre>

File conf.cfg

FW_USERNAME - ssh firewall login
FW_PASSWORD - ssh firewall password
FW_HOST - firewall ip/FQDN
FW_PORT - firewall ssh port
AD_LOGIN - microsoft active directory login
AD_PASSWD - microsoft active directory password
MAX_CHARS - login max lenght


File variaveis.cfg
RCPTMAIL="email@domain.com"
AD_HOST - microsoft active directory global catalog port
AD_BASEDN - microsoft active directory ldap base DN


Use:

./vpn.sh login final-date workstation-ip-address

./csvrun.sh file.csv

</pre>
