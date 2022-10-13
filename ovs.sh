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

echo "Check does the system handles virtualization:"
echo "VMX/SVM: " && egrep -c '(vmx|svm)' /proc/cpuinfo
if [ "egrep -c '(vmx|svm)' /proc/cpuinfo" != "0" ]; then

echo "update the system"
zypper ref
zypper up -y

echo "Change the hostname to kvm"
hostnamectl set-hostname kvm
hostnamectl

echo "Firewalld configuration"
firewall-cmd --permanent --zone=public --set-target=default
firewall-cmd --set-default-zone public
firewall-cmd --permanent --zone=public --change-interface=eth0
firewall-cmd --runtime-to-permanent
firewall-cmd --reload
firewall-cmd --list-all
systemctl restart firewalld.service

echo "OpenvSwitch installation"
zypper install -y openvswitch

echo "Check the status of services"

systemctl status openvswitch.service
systemctl start openvswitch.service
systemctl enable openvswitch.service
systemctl is-enabled openvswitch.service
systemctl status openvswitch.service

echo "Copy the eth0 to br-ex"
cp /etc/sysconfig/network/ifcfg-eth0 /etc/sysconfig/network/ifcfg-br-ex

## eth0 NIC
echo "Configure primary interface like below while replacing eth0 with the name of your physical interface."
sed -i 's/dhcp/none/g' /etc/sysconfig/network/ifcfg-eth0
cat /etc/sysconfig/network/ifcfg-eth0

## br-ex bridge
sed -i 's/auto/hotplug/g' /etc/sysconfig/network/ifcfg-br-ex
cat /etc/sysconfig/network/ifcfg-br-ex

echo "Change services: openvswitch.service, ovs-vswitchd.service and ovsdb-server.service"

sed -i 's/Before=network.target network.service/#Before=network.target network.service/g' /usr/lib/systemd/system/openvswitch.service
sed -i 's/PartOf=network.target/#PartOf=network.target/g' /usr/lib/systemd/system/openvswitch.service


sed -i 's/Before=network.target network.service/#Before=network.target network.service/g' /usr/lib/systemd/system/ovs-vswitchd.service

sed -i 's/Before=network.target network.service/#Before=network.target network.service/g' /usr/lib/systemd/system/ovsdb-server.service 
sed -i 's/After=syslog.target network-pre.target/After=syslog.target network-pre.target wicked.service/g' /usr/lib/systemd/system/ovsdb-server.service

sed -i 's/After=local-fs.target dbus.service isdn.service rdma.service network-pre.target SuSEfirewall2_init.service systemd-udev-settle.service openvswitch.service/After=local-fs.target dbus.service isdn.service rdma.service network-pre.target SuSEfirewall2_init.service systemd-udev-settle.service/g' /usr/lib/systemd/system/wickedd.service

# reload daemon
systemctl daemon-reload

systemctl restart ovs-vswitchd.service
systemctl restart ovsdb-server.service
systemctl restart openvswitch.service

## create open v switch bridge and add eth0 interface to the virtual bridge
echo "Add the eth0 physical interface to the br-ex bridge in openVswitch"
ovs-vsctl add-br br-ex
ovs-vsctl add-port br-ex eth0

# Add br-ex interface to firewalld and rtestart firewalld
firewall-cmd --permanent --zone=public --add-interface=br-ex
firewall-cmd --runtime-to-permanent
firewall-cmd --reload
firewall-cmd --list-all
systemctl restart firewalld.service

# Restart network
systemctl restart wicked.service

echo "List available OVS bridges"
ovs-vsctl show

echo "check the status of the virtual bridge br-ex"
ovs-vsctl show | grep -B 7 br-ex

echo "Check IP addresses"
ip a
echo "Check routing table"
ip r

#Check status for each service
systemctl status wicked.service
systemctl status openvswitch.service
systemctl status ovsdb-server.service
systemctl status ovs-vswitchd.service

else
	break;
fi
