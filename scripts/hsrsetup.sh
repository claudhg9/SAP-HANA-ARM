#!/bin/bash
set -x

# store arguments in a special array 
args=("$@") 
# get number of elements 
ELEMENTS=${#args[@]} 
 
# echo each element in array  
# for loop 
for (( i=0;i<$ELEMENTS;i++)); do 
    echo ${args[${i}]} 
done

URI=$1
shift
HANAUSR=$1
shift
HANAPWD=$1
shift
HANASID=$1
shift
HANANUMBER=$1
shift
VMSIZE=$1
shift
VMNAME=$1
shift
OTHERVMNAME=$1
shift
VMIPADDR=$1
shift
OTHERIPADDR=$1
shift
CONFIGHSR=$1

echo "domore receiving:"
echo "URI:" $URI
echo "HANAUSR:" $HANAUSR
echo "HANAPWD:" $HANAPWD
echo "HANASID:" $HANASID
echo "HANANUMBER:" $HANANUMBER
echo "VMSIZE:" $VMSIZE
echo "VMNAME:" $VMNAME
echo "OTHERVMNAME:" $OTHERVMNAME
echo "VMIPADDR:" $VMIPADDR
echo "OTHERIPADDR:" $OTHERIPADDR
echo "CONFIGHSR:" $CONFIGHSR

#we need to fix up the hosts.txt file

#zypper install -y python-pip
#pip install sshpt

#cat >>/etc/hosts <<EOF
#$VMIPADDR $VMNAME
#$OTHERIPADDR $OTHERVMNAME
#EOF

cd ~/
rm -r -f .ssh
cat /dev/zero |ssh-keygen -q -N "" > /dev/null

sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "mkdir -p /root/.ssh"
sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo -c ~/.ssh/id_rsa.pub -d /root/
sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "mkdir /root/.ssh"
sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "mv /root/id_rsa.pub /root/.ssh/authorized_keys"
sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "chmod 700 /root/.ssh"
sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "chown root:root /root/.ssh/authorized_keys"
sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "chmod 700 /root/.ssh/authorized_keys"

#sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "ls -la /root"
#sshpt --hosts hana2 -u $HANAUSR -p $HANAPWD --sudo "ls -la /root/.ssh"


cat >hdbsetup <<EOF
#!/bin/bash
PATH="\$PATH:/usr/sap/SLE/HDB00/exe"
SYNCUSER="hsrsync"
SYNCPASSWORD="Repl1cate"

HANASID=h10
HANANUMBER=00

hdbuserstore SET systemloc localhost:30015 system AweS0me@PW

hdbsql -U systemloc -i 00 "CREATE USER \$SYNCUSER PASSWORD \$SYNCPASSWORD"
hdbsql -U systemloc -i 00 "grant data admin to \$SYNCUSER"
hdbsql -U systemloc -i 00 "ALTER USER \$SYNCUSER DISABLE PASSWORD LIFETIME"
hdbsql -U systemloc -i 00 "backup data using file ('initial backup')"
hdbsql -U systemloc -i 00 "BACKUP DATA for \$HANASID USING FILE ('backup')"
hdbsql -U systemloc -i 00 "BACKUP DATA for SYSTEMDB USING FILE ('SYSTEMDB backup')"

hdbnsutil -sr_enable --name=SYSTEM0

EOF

cp ./hdbsetup /usr/sap/$HANASID/HDB$HANANUMBER/hdbsetup
chown $HANAUSER:sapsys /usr/sap/$HANASID/HDB$HANANUMBER/hdbsetup
chmod u+x /usr/sap/$HANASID/HDB$HANANUMBER/hdbsetup
su - -c "bash /usr/sap/$HANASID/HDB$HANANUMBER/hdbsetup" $HANAUSER 

scp -o StrictHostKeyChecking=no hdbsetup root@hana2:/root/hdbsetup
exit



scp /usr/sap/H10/SYS/global/security/rsecssfs/data/SSFS_H10.DAT h10adm@hsrtest2:/usr/sap/H10/SYS/global/security/rsecssfs/data/SSFS_H10.DAT
scp /usr/sap/H10/SYS/global/security/rsecssfs/key/SSFS_H10.KEY h10adm@hsrtest2:/usr/sap/H10/SYS/global/security/rsecssfs/key/SSFS_H10.KEY

stop the second server
sapcontrol -nr 00 -function StopSystem HDB
h10adm@hsrtest2:/usr/sap/H10/HDB00> hdbrsutil -f -k -p 30003
h10adm@hsrtest2:/usr/sap/H10/HDB00> hdbrsutil -f -k -p 30001
as root do:
systemctl stop sapinit.service


hdbnsutil -sr_register --name=system1 --remoteHost=hsrtest2 --remoteInstance=00 --replicationMode=sync --operationMode=logreplay

