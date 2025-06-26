'''
    This is a basic bcc python program to quanitfy the IO operations being performed on the 
    LUNs through the initiator using metrics like:
        - read and write bytes per second
        - average size of I/Os per second, etc.

    Before executing this: 
        sudo apt install -y bpfcc-tools libbpfcc-dev 
        pip install bcc
'''

from bcc import BPF
from collections import defaultdict
import ctypes as ct
import time
import os

MONITORED_MAJOR_DEV = [8]  # sdX drives

bpf_text = """
    #include <linux/blkdev.h>
    #include <linux/types.h>

    struct data_t {
        u32 major;
        u32 minor;
        u32 bytes;
        u8 rwflag;
    };

    BPF_PERF_OUTPUT(events);

    TRACEPOINT_PROBE(block, block_rq_issue) {
        struct data_t data = {};
        data.major = MAJOR(args->dev);
        data.minor = MINOR(args->dev);
        data.bytes = args->nr_sector * 512;
        data.rwflag = args->rwbs[0] == 'W';  // simple R/W flag
        events.perf_submit(args, &data, sizeof(data));
        return 0;
    }
"""

class Data(ct.Structure):
    _fields_ = [
        ("major", ct.c_uint),
        ("minor", ct.c_uint),
        ("bytes", ct.c_uint),
        ("rwflag", ct.c_ubyte),
    ]

read_bytes = defaultdict(int)
write_bytes = defaultdict(int)
read_count = defaultdict(int)
write_count = defaultdict(int)

b = BPF(text=bpf_text)

def handle_event(cpu, data, size):
    event = ct.cast(data, ct.POINTER(Data)).contents
    if event.major not in MONITORED_MAJOR_DEV:
        return
    key = f"{event.major}:{event.minor}"
    if event.rwflag:
        write_bytes[key] += event.bytes
        write_count[key] += 1
    else:
        read_bytes[key] += event.bytes
        read_count[key] += 1

b["events"].open_perf_buffer(handle_event)

def clear():
    os.system("clear")

print("Tracking block I/O... Press Ctrl+C to stop.")
try:
    while True:
        start = time.time()
        while time.time() - start < 1:
            b.perf_buffer_poll(timeout=100)

        clear()
        print(f"{'DEVICE':<10} {'READ KB/s':>10} {'WRIT KB/s':>10} {'READ IO/s':>10} {'WRIT IO/s':>10} {'AVG R IO (KB)':>14} {'AVG W IO (KB)':>14}")
        print("-" * 80)
        devices = set(read_bytes.keys()) | set(write_bytes.keys()) | set(read_count.keys()) | set(write_count.keys())
        for dev in sorted(devices):
            rbytes = read_bytes.get(dev, 0)
            wbytes = write_bytes.get(dev, 0)
            rcnt = read_count.get(dev, 0)
            wcnt = write_count.get(dev, 0)
            avg_rio = (rbytes / rcnt / 1024) if rcnt > 0 else 0
            avg_wio = (wbytes / wcnt / 1024) if wcnt > 0 else 0
            print(f"{dev:<10} {rbytes/1024:10.2f} {wbytes/1024:10.2f} {rcnt:10d} {wcnt:10d} {avg_rio:14.2f} {avg_wio:14.2f}")

        read_bytes.clear()
        write_bytes.clear()
        read_count.clear()
        write_count.clear()
except KeyboardInterrupt:
    print("\nStopped.")
