## **What is iSCSI**
iSCSI (Internet Small Computer Systems Interface) is a transport layer protocol that allows you to send SCSI* commands over TCP/IP networks, letting a computer to use storage devices over a network as if they were local disks.

_*SCSI (Small Computer System Interface) operates locally as an input-output bus that uses a common command set to transfer controls and data to all devices_

* It makes set up of a shared-storage network possible, where multiple servers and clients can access central storage resources as if the storage was a locally connected device

The main use cases of iSCSI are:
* Creating and managing Storage Area Networks (SANs) - high-speed dedicated networks that are tailored to specific environments, connecting servers to shared storage devices.

* Enabling centralized storage for servers

* Providing a scalable storage solution for virtualized environments

* Backup and Recovery operations

---

## **Components of iSCSI**

### **iSCSI Target**
The iSCSI target is the _storage provider_. It runs server software that exports block-level storage over the network using the iSCSI protocol.

* Can be a physical disk array, NAS device, or even software-defined storage on a Linux/Windows server.

* Hosts one or more LUNs (Logical Units) that are accessible to initiators.

* Responds to iSCSI SCSI commands (like read/write) sent over TCP/IP.

* Ensures data integrity, access control, and performance based on configuration.

Target-cli and TGT are the most common open-source methods used to set up an iSCSI target on Linux


### **iSCSI Initiator**
The iSCSI initiator is the _client-side component_ that connects to the target to access remote storage.

* Usually a server or VM that needs storage.

* Sends SCSI commands (e.g., read, write) over TCP/IP to the target.

* Treats the remote LUNs as if they were local block devices (e.g., /dev/sdX on Linux).

* Requires initiator software, which is typically built into the OS.

* Target-cli and TGT are the most common open-source methods used to set up an iSCSI target

open-iscsi (iscsiadm and iscsid) is the most common open-source methods used to set up an iSCSI target on Linux

### **iSCSI setup on two virtual machines**

1. **Target**

* Install `target-cli` and enable on the system.

* Ensure that the firewall is not blocking the port that is used by your target to listen for iSCSI commands.

* Create disks for each lun present in the iscsi folder present on the target system using this command: `create disk /iscsi_luns/lun.img`

* Next create an iqn for the target in `/iscsi/` and create luns corresponding to the previously created disks.

* Create an iqn in the `/acls/` directory using the initiator's iqn value. This step ensures that the system is mapped to the luns

* Set authentication of `tpg1` to 1 if required and set the `username` and `password` in the initiator iqn folder.

* Save the configuration in the root `/` before exiting.

![target setup](assets/target.png)

2. **Initator**

* Install `open-iscsi` on the initiator system and enable `iscsiadm` on the system.

* Search for targets using the `sudo iscsiadm -m discovery -t sendtargets -p <TARGET_IP>` command. If the target is up and running, you can see its IP address and iqn value.

* After discovery, log into the target using this command: `sudo iscsiadm -m node -T <TARGET_NAME> -p <TARGET_IP> --login`

![initiator login](<assets/login_init.png>)

* After successfully logging in, run the `lsblk` command to see the available luns.

* These luns can then be mounted and used later!

![iscsi setup successful!](assets/image.png)