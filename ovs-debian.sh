#!/bin/bash
echo "This quick installer script requires root privileges."
echo "Checking..."
if [[ $(/usr/bin/id -u) -ne 0 ]]; 
then
    echo "Not running as root"
    exit 0
else
        echo "Installation continues"
fi

SUDO=
if [ "$UID" != "0" ]; then
        if [ -e /usr/bin/sudo -o -e /bin/sudo ]; then
                SUDO=sudo
        else
                echo "*** This quick installer script requires root privileges."
                exit 0
        fi
fi

apt update
apt upgrade -y
apt install sudo
echo "sudoers configuration"
# Add group admins to sudoers
sed -i 's/%sudo/%admins/g' /etc/sudoers
echo "%admins ALL=(ALL:ALL) NOPASSWD: ALL" >> /etc/sudoers
cat /etc/sudoers

echo "user's configuration"
# Add group admins
groupadd admins
# Add a user to a group admins
usermod -a -G admins adrian
# Check is the user in admins group
id adrian

echo "Check does the system handles virtualization:"
echo "VMX/SVM: " && egrep -c '(vmx|svm)' /proc/cpuinfo

if [ "egrep -c '(vmx|svm)' /proc/cpuinfo" != "0" ]; then
        hostnamectl set-hostname kvm
        hostnamectl
        apt install -y bridge-utils openvswitch-common openvswitch-switch firewalld
        echo "Firewalld configuration"
        firewall-cmd --permanent --zone=public --set-target=default
        firewall-cmd --set-default-zone public
        firewall-cmd --permanent --zone=public --change-interface=enp0s25
        firewall-cmd --runtime-to-permanent
        firewall-cmd --reload
        firewall-cmd --list-all
        systemctl restart firewalld.service
        systemctl status firewalld.service
        systemctl status openvswitch-switch.service
        echo "dns-nameservers 10.10.0.100" >> /etc/network/interfaces
        echo "# IP configuration of the OVS Bridge" >> /etc/network/interfaces
        echo "allow-hotplug br-ex" >> /etc/network/interfaces
        echo "allow-ovs br-ex" >> /etc/network/interfaces
        echo "iface br-ex inet dhcp" >> /etc/network/interfaces
        echo "dns-nameservers 10.10.0.100" >> /etc/network/interfaces
        echo "ovs_type OVSBridge" >> /etc/network/interfaces
        echo "ovs_ports enp0s25" >> /etc/network/interfaces
        cat /etc/network/interfaces
        echo "Change services: openvswitch-switch.service, ovs-vswitchd.service and ovsdb-server.service"
        sed -i 's/Before=network.target/#Before=network.target/g' /usr/lib/systemd/system/openvswitch-switch.service
        sed -i 's/PartOf=network.target/#PartOf=network.target/g' /usr/lib/systemd/system/openvswitch-switch.service
        sed -i 's/Before=network.target networking.service/#Before=network.target networking.service/g' /usr/lib/systemd/system/ovs-vswitchd.service
        sed -i 's/Before=network.target networking.service/#Before=network.target networking.service/g' /usr/lib/systemd/system/ovsdb-server.service 
        sed -i 's/After=syslog.target network-pre.target dpdk.service local-fs.target/After=syslog.target network-pre.target dpdk.service local-fs.target networking.service/g' /usr/lib/systemd/system/ovsdb-server.service
        systemctl daemon-reload
        systemctl restart ovs-vswitchd.service
        systemctl restart ovsdb-server.service
        systemctl restart openvswitch-switch.service
        echo "Add virtual bridge br-ex"
        ovs-vsctl add-br br-ex
        echo "check the status of the virtual bridge br-ex"
        ovs-vsctl show | grep -B 7 br-ex
        firewall-cmd --permanent --zone=public --add-interface=enp0s25
        firewall-cmd --permanent --zone=public --add-interface=br-ex
        firewall-cmd --reload
        firewall-cmd --list-all
        ovs-vsctl add-port br-ex enp0s25 && reboot
else
        break;
fi
