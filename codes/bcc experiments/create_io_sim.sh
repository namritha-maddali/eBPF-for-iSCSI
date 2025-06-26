#!/bin/bash

# script to pre-fill iSCSI LUNs and then run a combined Fio test workload.
# this script should be run on the iSCSI Initiator client machine.
# execute using: ./create_io_sim.sh

# --- Configuration Variables ---
LUN1_MOUNT_POINT="/mnt/iscsi_lun1"
LUN2_MOUNT_POINT="/mnt/iscsi_lun2"
LUN3_MOUNT_POINT="/mnt/iscsi_lun3"

TEST_FILE_SIZE="250M" 
PREFILL_BS="1M"      # block size for pre-filling
MAIN_TEST_BS="4k"    # block size for the main mixed R/W test
TEST_RUNTIME="120"   # runtime for the main Fio test in seconds

FIO_JOB_FILE="io_test.fio" # Name of the Fio job file

echo "--- Creating test files ---"

sudo fio --name=prefill_lun1 \
--filename="${LUN1_MOUNT_POINT}/test_file_lun1" \
--size="${TEST_FILE_SIZE}" \
--rw=write \
--bs="${PREFILL_BS}" \
--direct=1 \
--numjobs=1 \
--iodepth=1 \
--runtime=120 \
--fsync=1 --end_fsync=1 || { echo "Prefill for LUN1 failed. Exiting."; exit 1; }

sudo fio --name=prefill_lun2 \
--filename="${LUN2_MOUNT_POINT}/test_file_lun2" \
--size="${TEST_FILE_SIZE}" \
--rw=write \
--bs="${PREFILL_BS}" \
--direct=1 \
--numjobs=1 \
--iodepth=1 \
--runtime=120 \
--fsync=1 \
--end_fsync=1 || { echo "Prefill for LUN2 failed. Exiting."; exit 1; }

sudo fio --name=prefill_lun3 \
--filename="${LUN3_MOUNT_POINT}/test_file_lun3" \
--size="${TEST_FILE_SIZE}" \
--rw=write \
--bs="${PREFILL_BS}" \
--direct=1 \
--numjobs=1 \
--iodepth=1 \
--runtime=120 \
--fsync=1 \
--end_fsync=1 || { echo "Prefill for LUN3 failed. Exiting."; exit 1; }

echo "--- Test Files Created ---"

# --- The Fio File ---
cat <<EOF > "${FIO_JOB_FILE}"
[global]
ioengine=libaio
direct=1
buffered=0
numjobs=1
iodepth=16
bs=${MAIN_TEST_BS}
runtime=${TEST_RUNTIME}
group_reporting
time_based
randrepeat=0

[lun1_read_job]
filename=${LUN1_MOUNT_POINT}/test_file_lun1
size=${TEST_FILE_SIZE}
rw=randread

[lun2_read_job]
filename=${LUN2_MOUNT_POINT}/test_file_lun2
size=${TEST_FILE_SIZE}
rw=randread

[lun3_write_job]
filename=${LUN3_MOUNT_POINT}/test_file_lun3
size=${TEST_FILE_SIZE}
rw=randwrite
EOF

echo "Fio job file created."