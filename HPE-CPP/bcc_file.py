from bcc import BPF
from collections import defaultdict
import ctypes as ct
import time
import os
import glob
import json

STATE_FILE = "/usr/local/bin/node_exporter/textfile_collector/iscsi_metrics_state.json"
EXPORT_FILE = "/usr/local/bin/node_exporter/textfile_collector/iscsi_metrics.prom"
TMP_FILE = "/tmp/iscsi.prom.tmp"

# In-memory metric state
read_bytes = defaultdict(int)
write_bytes = defaultdict(int)
read_count = defaultdict(int)
write_count = defaultdict(int)

def save_state():
    with open(STATE_FILE, "w") as f:
        json.dump({
            "read_bytes": dict(read_bytes),
            "write_bytes": dict(write_bytes),
            "read_count": dict(read_count),
            "write_count": dict(write_count)
        }, f)

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
            read_bytes.update({k: int(v) for k, v in state.get("read_bytes", {}).items()})
            write_bytes.update({k: int(v) for k, v in state.get("write_bytes", {}).items()})
            read_count.update({k: int(v) for k, v in state.get("read_count", {}).items()})
            write_count.update({k: int(v) for k, v in state.get("write_count", {}).items()})

def get_iscsi_devices():
    iscsi_devs = set()
    for link in glob.glob("/dev/disk/by-path/*-iscsi-*"):
        try:
            realpath = os.path.realpath(link)
            stat_info = os.stat(realpath)
            major = os.major(stat_info.st_rdev)
            minor = os.minor(stat_info.st_rdev)
            iscsi_devs.add((major, minor))
        except FileNotFoundError:
            continue
    return iscsi_devs

MONITORED_DEVICES = get_iscsi_devices()

bpf_text = """
#include <uapi/linux/ptrace.h>

struct data_t {
    u32 major;
    u32 minor;
    u64 bytes;
    u8 rwflag;
};

BPF_PERF_OUTPUT(events);

struct block_rq_issue_args {
    unsigned long long pad;
    dev_t dev;
    struct request *rq;
    sector_t sector;
    unsigned int nr_sectors;
    unsigned int bytes;
    int rwbs_len;
    char rwbs[8];
    int cmd_len;
    char cmd[16];
};

int tracepoint__block__block_rq_issue(struct block_rq_issue_args *args) {
    struct data_t data = {};
    data.major = args->dev >> 20;
    data.minor = args->dev & ((1 << 20) - 1);
    data.bytes = args->nr_sectors << 9;
    if (args->rwbs[0] == 'R' || args->rwbs[0] == 'r') {
        data.rwflag = 0; // read
    } else {
        data.rwflag = 1; // write
    }
    events.perf_submit(args, &data, sizeof(data));
    return 0;
}

// Extra metric: count iscsi_data_xmit calls
BPF_HASH(xmit_count, u32, u64);

int trace_iscsi_xmit(struct pt_regs *ctx) {
    u32 key = 0;
    u64 *val = xmit_count.lookup(&key);
    if (val) (*val)++;
    else {
        u64 one = 1;
        xmit_count.update(&key, &one);
    }
    return 0;
}
"""

class Data(ct.Structure):
    _fields_ = [
        ("major", ct.c_uint),
        ("minor", ct.c_uint),
        ("bytes", ct.c_ulonglong),
        ("rwflag", ct.c_ubyte),
    ]

b = BPF(text=bpf_text)
b.attach_kprobe(event="iscsi_data_xmit", fn_name="trace_iscsi_xmit")

def handle_event(cpu, data, size):
    event = ct.cast(data, ct.POINTER(Data)).contents
    key_tuple = (event.major, event.minor)
    key = f"{event.major}:{event.minor}"
    if key_tuple not in MONITORED_DEVICES:
        return
    print(f"[DEBUG] Event - Dev: {key}, Bytes: {event.bytes}, RW: {'READ' if event.rwflag == 0 else 'WRITE'}")
    if event.rwflag == 0:
        read_bytes[key] += event.bytes
        read_count[key] += 1
    else:
        write_bytes[key] += event.bytes
        write_count[key] += 1

b["events"].open_perf_buffer(handle_event)

def write_prometheus_file():
    with open(TMP_FILE, "w") as f:
        f.write("# HELP iscsi_read_bytes Total read bytes per iSCSI device\n")
        f.write("# TYPE iscsi_read_bytes counter\n")
        for dev, val in read_bytes.items():
            f.write(f'iscsi_read_bytes{{device="{dev}"}} {val}\n')

        f.write("# HELP iscsi_write_bytes Total written bytes per iSCSI device\n")
        f.write("# TYPE iscsi_write_bytes counter\n")
        for dev, val in write_bytes.items():
            f.write(f'iscsi_write_bytes{{device="{dev}"}} {val}\n')

        f.write("# HELP iscsi_read_ops Total read I/O operations per iSCSI device\n")
        f.write("# TYPE iscsi_read_ops counter\n")
        for dev, val in read_count.items():
            f.write(f'iscsi_read_ops{{device="{dev}"}} {val}\n')

        f.write("# HELP iscsi_write_ops Total write I/O operations per iSCSI device\n")
        f.write("# TYPE iscsi_write_ops counter\n")
        for dev, val in write_count.items():
            f.write(f'iscsi_write_ops{{device="{dev}"}} {val}\n')

        f.write("# HELP iscsi_func_calls Number of times iscsi_data_xmit was called\n")
        f.write("# TYPE iscsi_func_calls counter\n")
        xmit_table = b.get_table("xmit_count")
        for k, v in xmit_table.items():
            f.write(f'iscsi_func_calls{{func="iscsi_data_xmit"}} {v.value}\n')

    os.rename(TMP_FILE, EXPORT_FILE)

# Load persisted stats
load_state()
print("Previous state loaded.")
print("Tracking iSCSI block I/O... Press Ctrl+C to stop.")
print(f"Monitoring devices: {[f'{m}:{n}' for (m, n) in MONITORED_DEVICES]}")

try:
    while True:
        start = time.time()
        while time.time() - start < 1:
            b.perf_buffer_poll(timeout=100)
        for key in MONITORED_DEVICES:
            key_str = f"{key[0]}:{key[1]}"
            if key_str not in read_bytes:
                read_bytes[key_str] += 0
                read_count[key_str] += 0
        write_prometheus_file()
except KeyboardInterrupt:
    save_state()
    print("\nStopped and state saved.")

