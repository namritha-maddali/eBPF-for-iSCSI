#!/bin/bash

echo " Create the backing image"
sudo mkdir -p /var/iscsi_disks
sudo truncate -s 1G /var/iscsi_disks/lun1.img

# Feed commands into targetcli non-interactively
sudo targetcli <<EOF
/backstores/fileio create disk1 /var/iscsi_disks/lun1.img 1G
/iscsi create iqn.2025-06.com.example:uml
/iscsi/iqn.2025-06.com.example:uml/tpg1/luns create /backstores/fileio/disk1
/iscsi/iqn.2025-06.com.example:uml/tpg1/acls create iqn.1994-05.com.initiator:client
/iscsi/iqn.2025-06.com.example:uml/tpg1/portals create 0.0.0.0 3260
/iscsi/iqn.2025-06.com.example:uml/tpg1 set attribute generate_node_acls=1
/iscsi/iqn.2025-06.com.example:uml/tpg1 set attribute authentication=0
/iscsi/iqn.2025-06.com.example:uml/tpg1 set attribute demo_mode_write_protect=0
exit
EOF

echo "[INFO] Discovering and logging into iSCSI LUN target"
sudo iscsiadm -m discovery -t sendtargets -p 127.0.0.1
sudo iscsiadm -m discovery -t sendtargets -p 10.10.3.111
sudo iscsiadm -m node --login

echo "Verify using lsblk"
lsblk 
sleep 15

#echo "Format the LUN"
#sudo mkfs.ext4 /dev/sdb

echo "Repair LUN"
sudo fsck -y /dev/sdc

echo "Format the LUN"
sudo mkfs.ext4 /dev/sdc

