#!/bin/bash
#auth:peter
#build open-falcon agent for CentOS 6/7 Ubuntu16

LinuxAgent="falcon-linux-agent.tar.gz"
MirrorsURL="download.eveb.inc:9999"
APPDIR="/usr/local/server"
SRCDIR="/usr/local/src"
#TIME_ZONE="ntp.org.cn"

HN=$1
if [[ $uid -ne 0 ]];then
   echo -e "please used users by root!"
   exit 1
fi
checkHost(){
 #grep $(hostname) /etc/hosts || echo "127.0.0.1 $(hostname)" >> /etc/hosts;
  sed -i '-e /download\.eveb\.inc/d' /etc/hosts;
  cat /etc/hosts|grep mirrors||echo "161.202.145.68 download.eveb.inc" >> /etc/hosts;
}

GetOSVersion()
{
    if grep -Eqi "CentOS" /etc/issue || grep -Eq "CentOS" /etc/*-release; then
        DISTRO='CentOS'
        OSVERSION=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
        yum install wget tar git -y
    elif grep -Eqi "Red Hat Enterprise Linux Server" /etc/issue || grep -Eq "Red Hat Enterprise Linux Server" /etc/*-release; then
        DISTRO='RHEL'
        OSVERSION=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
              
    elif grep -Eqi "Ubuntu" /etc/issue || grep -Eq "Ubuntu" /etc/*-release; then
        DISTRO='Ubuntu'
        OSVERSION=`cat /etc/issue|grep -Po '1[0-9].\d+'`
        OS_VERSION="Ubuntu$OSVERSION"
        apt install wget tar git -y
    fi

    if [ "$DISTRO" == "CentOS" ] && [ "$OSVERSION" == "6" ];then
        OS_VERSION='CentOS6'
    elif [ "$DISTRO" == "CentOS" ] && [ "$OSVERSION" == "7" ];then
        OS_VERSION='CentOS7'
    elif [ "$DISTRO" == "Ubuntu" ] && [ "$OSVERSION" == "16.04" ];then
        OS_VERSION='Ubuntu16.04'
    fi
}

SetHostName()
{
    #read -p 'Do you want set hostname now?(yes[Y/y] or no[N/n])' flag
    #read -p 'Starting set server hostname,please input hostname:' HN  
        if  [ "$OS_VERSION" == "CentOS7" ];then
            sudo hostnamectl set-hostname $HN
            if [ "$?" != "0" ];then
                echo "server hostname setting error,please check it"
                exit 1;
            fi
        elif [ "$OS_VERSION" == "CentOS6" ];then
            sudo hostname $HN
            sed -i 's/^HOSTNAME.*/HOSTNAME='$HN'/g' /etc/sysconfig/network
        elif [ "$DISTRO" == "Ubuntu" ];then
            sudo hostnamectl set-hostname $HN
            if [ "$?" != "0" ];then
                echo "server hostname setting error,please check it"
                exit 1;
            fi

        fi
        echo "server hostname : $(hostname)"
        grep $HN /etc/hosts || echo "127.0.0.1 $HN" >> /etc/hosts
}

SetTimeZone()
{
        if [ "$DISTRO" == "Ubuntu" ];then
            #ps -ef|grep ntpd|grep -v grep && systemctl stop ntpd.service
            #systemctl disable nptd.service            
            #dpkg -l|grep chrony ||sudo apt-get install chrony -y
            #systemctl start chronyd.service
            #systemctl enable chronyd
            timedatectl status|grep 'Shanghai' || timedatectl set-timezone Asia/Shanghai
            timedatectl status|grep 'NTP synchronized: yes'|| timedatectl set-ntp yes
            #timedatectl set-timezone UTC
        elif  [ "$OS_VERSION" == "CentOS7" ];then
            ps -ef|grep ntpd|grep -v grep && systemctl stop ntpd.service
            systemctl disable nptd.service
            rpm -qa|grep chrony || yum install chrony -y
            systemctl start chronyd
            systemctl enable chronyd
            timedatectl set-timezone Asia/Shanghai
            timedatectl set-ntp yes
            chronyc activity
        elif  [ "$OS_VERSION" == "CentOS6" ];then
            rpm -qa|grep ntpd && service nptd stop
            chkconifg ntpd off
            date|grep ShangHai|| \cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime                      
            rpm -qa|grep chrony || yum install chrony -y
            service chronyd start
            chkconfig chronyd on
            chronyc activity

        fi      
}

DeployInstall()
{
    [ -d "$APPDIR" ] || mkdir -p $APPDIR;
    [ -d "$SRCDIR" ] || mkdir -p $SRCDIR;   
    if [ -d "$APPDIR/falcon-agent" ];then
        echo "falcon-agent dir is exist,please check it"
        exit 1
    fi
    if [ ! -f "$LinuxAgent" ];then
        wget -P $SRCDIR $MirrorsURL/$LinuxAgent;
    fi
    tar zxvf $SRCDIR/$LinuxAgent -C $APPDIR/
    chmod +x $APPDIR/falcon-agent/bin/falcon-agent
    cd $APPDIR/falcon-agent && nohup ./bin/falcon-agent -c ./config/cfg.json >/tmp/falcon-agent.log 2>&1 & 
    sleep 1;
    STARTUP="cd $APPDIR/falcon-agent && nohup ./bin/falcon-agent -c ./config/cfg.json >/tmp/falcon-agent.log 2>&1 &"
    if [ "$DISTRO" == "CentOS" ];then
        grep falcon-agent /etc/rc.d/rc.local||sed -i "$ i$STARTUP" /etc/rc.d/rc.local
        chmod +x /etc/rc.d/rc.local
    elif [ "$DISTRO" == "Ubuntu" ];then
        grep falcon-agent /etc/rc.local||sed -i "$ i$STARTUP" /etc/rc.local
        chmod +x /etc/rc.local
    fi

    ps -ef|grep falcon-agent|grep -v grep 
    if [ "$?" == "0" ];then
        echo -e "open-falcon agent install successfully!"           
        echo -e "please set up open-falcon server iptables add this ip address: $(curl -s https://ip.cn|grep -Po '\d+\.\d+\.\d+\.\d+')"
    else
        echo -e "open-falcon agent install failed, please check it!"
    fi
}   
checkHost
GetOSVersion
SetHostName
SetTimeZone
DeployInstall
