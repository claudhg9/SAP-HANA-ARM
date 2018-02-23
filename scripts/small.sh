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
shift
ISPRIMARY=$1
shift
REPOURI=$1


HANASIDU="${HANASID^^}"
HANASIDL="${HANASID,,}"

HANAADMIN="$HANASIDL"adm
echo "HANAADMIN:" $HANAADMIN

echo "small.sh receiving:"
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
echo "ISPRIMARY:" $ISPRIMARY
echo "REPOURI:" $REPOURI

#install hana prereqs
sudo zypper install -y glibc-2.22-51.6
sudo zypper install -y systemd-228-142.1
sudo zypper install -y unrar
sudo zypper install -y sapconf
sudo zypper install -y saptune
sudo mkdir /etc/systemd/login.conf.d
sudo mkdir /hana
sudo mkdir /hana/data
sudo mkdir /hana/log
sudo mkdir /hana/shared
sudo mkdir /hana/backup
sudo mkdir /usr/sap


# Install .NET Core and AzCopy
sudo zypper install -y libunwind
sudo zypper install -y libicu
curl -sSL -o dotnet.tar.gz https://go.microsoft.com/fwlink/?linkid=848824
sudo mkdir -p /opt/dotnet && sudo tar zxf dotnet.tar.gz -C /opt/dotnet
sudo ln -s /opt/dotnet/dotnet /usr/bin

wget -O azcopy.tar.gz https://aka.ms/downloadazcopyprlinux
tar -xf azcopy.tar.gz
sudo ./install.sh

sudo zypper in -t -y pattern sap-hana

# step2
echo $URI >> /tmp/url.txt

cp -f /etc/waagent.conf /etc/waagent.conf.orig
sedcmd="s/ResourceDisk.EnableSwap=n/ResourceDisk.EnableSwap=y/g"
sedcmd2="s/ResourceDisk.SwapSizeMB=0/ResourceDisk.SwapSizeMB=163840/g"
cat /etc/waagent.conf | sed $sedcmd | sed $sedcmd2 > /etc/waagent.conf.new
cp -f /etc/waagent.conf.new /etc/waagent.conf

number="$(lsscsi [*] 0 0 4| cut -c2)"

echo "logicalvols start" >> /tmp/parameter.txt
  hanavg1lun="$(lsscsi $number 0 0 3 | grep -o '.\{9\}$')"
  hanavg2lun="$(lsscsi $number 0 0 4 | grep -o '.\{9\}$')"
  pvcreate $hanavg1lun $hanavg2lun
  vgcreate hanavg $hanavg1lun $hanavg2lun
  lvcreate -l 80%FREE -n datalv hanavg
  lvcreate -l 20%VG -n loglv hanavg
  mkfs.xfs /dev/hanavg/datalv
  mkfs.xfs /dev/hanavg/loglv
echo "logicalvols end" >> /tmp/parameter.txt


#!/bin/bash
echo "logicalvols2 start" >> /tmp/parameter.txt
  sharedvglun="$(lsscsi $number 0 0 0 | grep -o '.\{9\}$')"
  usrsapvglun="$(lsscsi $number 0 0 1 | grep -o '.\{9\}$')"
  backupvglun="$(lsscsi $number 0 0 2 | grep -o '.\{9\}$')"
  pvcreate $backupvglun $sharedvglun $usrsapvglun
  vgcreate backupvg $backupvglun
  vgcreate sharedvg $sharedvglun
  vgcreate usrsapvg $usrsapvglun 
  lvcreate -l 100%FREE -n sharedlv sharedvg 
  lvcreate -l 100%FREE -n backuplv backupvg 
  lvcreate -l 100%FREE -n usrsaplv usrsapvg 
  mkfs -t xfs /dev/sharedvg/sharedlv 
  mkfs -t xfs /dev/backupvg/backuplv 
  mkfs -t xfs /dev/usrsapvg/usrsaplv
echo "logicalvols2 end" >> /tmp/parameter.txt


#!/bin/bash
echo "mounthanashared start" >> /tmp/parameter.txt
mount -t xfs /dev/sharedvg/sharedlv /hana/shared
mount -t xfs /dev/backupvg/backuplv /hana/backup 
mount -t xfs /dev/usrsapvg/usrsaplv /usr/sap
mount -t xfs /dev/hanavg/datalv /hana/data
mount -t xfs /dev/hanavg/loglv /hana/log 
mkdir /hana/data/sapbits
echo "mounthanashared end" >> /tmp/parameter.txt

echo "write to fstab start" >> /tmp/parameter.txt
echo "/dev/mapper/hanavg-datalv /hana/data xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/hanavg-loglv /hana/log xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/sharedvg-sharedlv /hana/shared xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/backupvg-backuplv /hana/backup xfs defaults 0 0" >> /etc/fstab
echo "/dev/mapper/usrsapvg-usrsaplv /usr/sap xfs defaults 0 0" >> /etc/fstab
echo "write to fstab end" >> /tmp/parameter.txt

if [ ! -d "/hana/data/sapbits" ]
 then
 mkdir "/hana/data/sapbits"
fi



#!/bin/bash
cd /hana/data/sapbits
echo "hana download start" >> /tmp/parameter.txt
/usr/bin/wget --quiet $URI/SapBits/md5sums
/usr/bin/wget --quiet $URI/SapBits/51052325_part1.exe
/usr/bin/wget --quiet $URI/SapBits/51052325_part2.rar
/usr/bin/wget --quiet $URI/SapBits/51052325_part3.rar
/usr/bin/wget --quiet $URI/SapBits/51052325_part4.rar
/usr/bin/wget --quiet "https://raw.githubusercontent.com/AzureCAT-GSI/SAP-HANA-ARM/master/hdbinst.cfg"
echo "hana download end" >> /tmp/parameter.txt

date >> /tmp/testdate
cd /hana/data/sapbits

echo "hana unrar start" >> /tmp/parameter.txt
#!/bin/bash
cd /hana/data/sapbits
unrar x 51052325_part1.exe
echo "hana unrar end" >> /tmp/parameter.txt

echo "hana prepare start" >> /tmp/parameter.txt
cd /hana/data/sapbits

#!/bin/bash
cd /hana/data/sapbits
myhost=`hostname`
sedcmd="s/REPLACE-WITH-HOSTNAME/$myhost/g"
sedcmd2="s/\/hana\/shared\/sapbits\/51052325/\/hana\/data\/sapbits\/51052325/g"
sedcmd3="s/root_user=root/root_user=$HANAUSR/g"
sedcmd4="s/root_password=AweS0me@PW/root_password=$HANAPWD/g"
sedcmd5="s/master_password=AweS0me@PW/master_password=$HANAPWD/g"
sedcmd6="s/sid=H10/sid=$HANASID/g"
sedcmd7="s/number=00/number=$HANANUMBER/g"
cat hdbinst.cfg | sed $sedcmd | sed $sedcmd2 | sed $sedcmd3 | sed $sedcmd4 | sed $sedcmd5 | sed $sedcmd6 > hdbinst-local.cfg
echo "hana preapre end" >> /tmp/parameter.txt

#!/bin/bash
echo "install hana start" >> /tmp/parameter.txt
cd /hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64
/hana/data/sapbits/51052325/DATA_UNITS/HDB_LCM_LINUX_X86_64/hdblcm -b --configfile /hana/data/sapbits/hdbinst-local.cfg
echo "install hana end" >> /tmp/parameter.txt
echo "install hana end" >> /tmp/hanacomplete.txt
#
if [ "$CONFIGHSR" == "yes" ]; then
    echo "hsr config start" >> /tmp/parameter.txt	    
    HANASIDU="${HANASID^^}"
    #we need to fix up the hosts.txt file

    zypper install -y python-pip
    pip install sshpt

    cd /root
    wget $REPOURI/scripts/waitfor.sh
    chmod u+x waitfor.sh
    
    cat >>/etc/hosts <<EOF
$VMIPADDR $VMNAME
$OTHERIPADDR $OTHERVMNAME
EOF

    SYNCUSER="hsrsync"
    SYNCPASSWORD="Repl1cate"
    
    cat >/tmp/hdbsetupsql <<EOF
CREATE USER $SYNCUSER PASSWORD $SYNCPASSWORD;
grant data admin to $SYNCUSER;
ALTER USER $SYNCUSER DISABLE PASSWORD LIFETIME;
backup data using file ('initial backup');
BACKUP DATA for $HANASID USING FILE ('backup');
BACKUP DATA for SYSTEMDB USING FILE ('SYSTEMDB backup');
EOF

    chmod a+r /tmp/hdbsetupsql
    su - -c "hdbsql -u system -p $HANAPWD -d SYSTEMDB -I /tmp/hdbsetupsql" $HANAADMIN 

    #set up passwordless ssh on both sides
    cd ~/
    #rm -r -f .ssh
    cat /dev/zero |ssh-keygen -q -N "" > /dev/null

    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "mkdir -p /root/.ssh"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo -c ~/.ssh/id_rsa.pub -d /root/
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "mkdir /root/.ssh"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "mv /root/id_rsa.pub /root/.ssh/authorized_keys"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "chmod 700 /root/.ssh"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "chown root:root /root/.ssh/authorized_keys"
    sshpt --hosts $OTHERVMNAME -u $HANAUSR -p $HANAPWD --sudo "chmod 700 /root/.ssh/authorized_keys"
    
    touch /tmp/hanabackupdone.txt
    ./waitfor.sh root $OTHERVMNAME /tmp/hanabackupdone.txt

    
    if [ "$ISPRIMARY" = "yes" ]; then
	echo "hsr primary start" >> /tmp/parameter.txt	

	#now set the role on the primary
	cat >/tmp/srenable <<EOF
hdbnsutil -sr_enable --name=system0 	
EOF
	chmod a+r /tmp/srenable
	su - $HANAADMIN -c "bash /tmp/srenable"

	touch /tmp/readyforsecondary.txt
	./waitfor.sh root $OTHERVMNAME /tmp/readyforcerts.txt	
	scp /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/data/SSFS_$HANASIDU.DAT root@$OTHERVMNAME:/root/SSFS_$HANASIDU.DAT
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@$OTHERVMNAME "cp /root/SSFS_$HANASIDU.DAT /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/data/SSFS_$HANASIDU.DAT"
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@$OTHERVMNAME "chown $HANAADMIN:sapsys /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/data/SSFS_$HANASIDU.DAT"

	scp /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/key/SSFS_$HANASIDU.KEY root@$OTHERVMNAME:/root/SSFS_$HANASIDU.KEY
	ssh -o BatchMode=yes -o StrictHostKeyChecking=no root@$OTHERVMNAME "cp /root/SSFS_$HANASIDU.KEY /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/key/SSFS_$HANASIDU.KEY"
	ssh -o BatchMode=yes  -o StrictHostKeyChecking=no root@$OTHERVMNAME "chown $HANAADMIN:sapsys /usr/sap/$HANASIDU/SYS/global/security/rsecssfs/key/SSFS_$HANASIDU.KEY"

	touch /tmp/dohsrjoin.txt
    else
	#do stuff on the secondary
	./waitfor.sh root $OTHERVMNAME /tmp/readyforsecondary.txt	

	touch /tmp/readyforcerts.txt
	./waitfor.sh root $OTHERVMNAME /tmp/dohsrjoin.txt	
	cat >/tmp/hsrjoin <<EOF
sapcontrol -nr $HANANUMBER -function StopSystem HDB
hdbnsutil -sr_register --name=system1 --remoteHost=$OTHERVMNAME --remoteInstance=$HANANUMBER --replicationMode=sync --operationMode=logreplay
sapcontrol -nr $HANANUMBER -function StartSystem HDB
EOF

	chmod a+rwx /tmp/hsrjoin
	su - $HANAADMIN -c "bash /tmp/hsrjoin"
    fi
fi
#shutdown -r 1
