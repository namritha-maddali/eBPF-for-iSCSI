from bcc import BPF
from collections import defaultdict
import ctypes as ct
import time
import os
import glob
import json

STATE_FILE = "/usr/local/bin/node_exporter/textfile_collector/iscsi_metrics_state.json"
EXPORT_FILE = "/usr/local/bin/node_exporter/textfile_collector/iscsi_metrics.prom"

read_bytes = defaultdict(int)
write_bytes = defaultdict(int)
read_count = defaultdict(int)
write_count = defaultdict(int)
xmit_bytes = defaultdict(int)  # New for TCP send

def save_state():
    with open(STATE_FILE, "w") as f:
        json.dump({
            "read_bytes": dict(read_bytes),
            "write_bytes": dict(write_bytes),
            "read_count": dict(read_count),
            "write_count": dict(write_count),
            "xmit_bytes": dict(xmit_bytes)
        }, f)

def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE, "r") as f:
            state = json.load(f)
            read_bytes.update({k: int(v) for k, v in state.get("read_bytes", {}).items()})
            write_bytes.update({k: int(v) for k, v in state.get("write_bytes", {}).items()})
            read_count.update({k: int(v) for k, v in state.get("read_count", {}).items()})
            write_count.update({k: int(v) for k, v in state.get("write_count", {}).items()})
            xmit_bytes.update({k: int(v) for k, v in state.get("xmit_bytes", {}).items()})

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
#include <linux/blkdev.h>
#include <linux/types.h>
#include <net/sock.h>
#include <bcc/proto.h>

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
    if (args->rwbs[0] == 'R') {
        data.rwflag = 0;
    } else if (args->rwbs[0] == 'W') {
        data.rwflag = 1;
    } else {
        return 0;
    }
    events.perf_submit(args, &data, sizeof(data));
    return 0;
}

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

BPF_HASH(send_bytes, u16, u64);
int trace_tcp_sendmsg(struct pt_regs *ctx, struct sock *sk, struct msghdr *msg, size_t size) {
    u16 dport = sk->__sk_common.skc_dport;
    dport = ntohs(dport);
    if (dport == 3260) {
        u64 *val = send_bytes.lookup(&dport);
        if (val) (*val) += size;
        else {
            u64 size64 = size;
            send_bytes.update(&dport, &size64);
        }
    }
    return 0;
}

BPF_HASH(tcp_recv_bytes, u32, u64);
int trace_tcp_recvmsg(struct pt_regs *ctx, struct sock *sk, int copied) {
    u16 dport = 0;
    bpf_probe_read_kernel(&dport, sizeof(dport), &sk->__sk_common.skc_dport);
    dport = ntohs(dport);
    if (dport != 3260)
        return 0;

    u32 key = 0;
    u64 *val = tcp_recv_bytes.lookup(&key);
    if (val) (*val) += copied;
    else {
        u64 init = copied;
        tcp_recv_bytes.update(&key, &init);
    }
    return 0;
}

BPF_HASH(retransmit_count, u16, u64);
int trace_tcp_retransmit(struct pt_regs *ctx, struct sock *sk) {
    u16 dport = 0;
    bpf_probe_read_kernel(&dport, sizeof(dport), &sk->__sk_common.skc_dport);
    dport = ntohs(dport);
    if (dport != 3260) {
        return 0;
    }

    u64 *val = retransmit_count.lookup(&dport);
    if (val) (*val)++;
    else {
        u64 one = 1;
        retransmit_count.update(&dport, &one);
    }
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

b = BPF(text=bpf_text)
b.attach_kprobe(event="iscsi_data_xmit", fn_name="trace_iscsi_xmit")
b.attach_kprobe(event="tcp_sendmsg", fn_name="trace_tcp_sendmsg")
b.attach_kprobe(event="tcp_cleanup_rbuf", fn_name="trace_tcp_recvmsg")
b.attach_kprobe(event="tcp_retransmit_skb", fn_name="trace_tcp_retransmit")

def handle_event(cpu, data, size):
    event = ct.cast(data, ct.POINTER(Data)).contents
    key_tuple = (event.major, event.minor)
    if key_tuple not in MONITORED_DEVICES:
        return
    key = f"{event.major}:{event.minor}"
    if event.rwflag:
        write_bytes[key] += event.bytes
        write_count[key] += 1
    else:
        read_bytes[key] += event.bytes
        read_count[key] += 1

b["events"].open_perf_buffer(handle_event)

def write_prometheus_file():
    with open(EXPORT_FILE, "w") as f:
        # Ensure all device keys are initialized
        for (major, minor) in MONITORED_DEVICES:
            dev = f"{major}:{minor}"
            _ = read_bytes[dev]
            _ = write_bytes[dev]
            _ = read_count[dev]
            _ = write_count[dev]

        f.write("# HELP iscsi_read_bytes Total read bytes per iSCSI device\n")
        f.write("# TYPE iscsi_read_bytes counter\n")
        for dev in sorted(read_bytes.keys()):
            f.write(f'iscsi_read_bytes{{device="{dev}"}} {read_bytes[dev]}\n')

        f.write("# HELP iscsi_write_bytes Total written bytes per iSCSI device\n")
        f.write("# TYPE iscsi_write_bytes counter\n")
        for dev in sorted(write_bytes.keys()):
            f.write(f'iscsi_write_bytes{{device="{dev}"}} {write_bytes[dev]}\n')

        f.write("# HELP iscsi_read_ops Total read I/O operations per iSCSI device\n")
        f.write("# TYPE iscsi_read_ops counter\n")
        for dev in sorted(read_count.keys()):
            f.write(f'iscsi_read_ops{{device="{dev}"}} {read_count[dev]}\n')

        f.write("# HELP iscsi_write_ops Total write I/O operations per iSCSI device\n")
        f.write("# TYPE iscsi_write_ops counter\n")
        for dev in sorted(write_count.keys()):
            f.write(f'iscsi_write_ops{{device="{dev}"}} {write_count[dev]}\n')

        f.write("# HELP iscsi_func_calls Number of times iscsi_data_xmit was called\n")
        f.write("# TYPE iscsi_func_calls counter\n")
        xmit_table = b.get_table("xmit_count")
        count = 0
        for k, v in xmit_table.items():
            count += v.value
        f.write(f'iscsi_func_calls{{func="iscsi_data_xmit"}} {count}\n')

        f.write("# HELP iscsi_tcp_sent_bytes Total TCP bytes sent on port 3260\n")
        f.write("# TYPE iscsi_tcp_sent_bytes counter\n")
        send_table = b.get_table("send_bytes")
        if not send_table:
            f.write('iscsi_tcp_sent_bytes{port="3260"} 0\n')
        else:
            for k, v in send_table.items():
                f.write(f'iscsi_tcp_sent_bytes{{port="{k.value}"}} {v.value}\n')

        f.write("# HELP iscsi_tcp_recv_bytes Total received TCP bytes for iSCSI traffic\n")
        f.write("# TYPE iscsi_tcp_recv_bytes counter\n")
        recv_table = b.get_table("tcp_recv_bytes")
        if not recv_table:
            f.write('iscsi_tcp_recv_bytes{port="0"} 0\n')
        else:
            for k, v in recv_table.items():
                f.write(f'iscsi_tcp_recv_bytes{{port="{k.value}"}} {v.value}\n')

        f.write("# HELP iscsi_tcp_retransmits Total number of TCP retransmissions on port 3260\n")
        f.write("# TYPE iscsi_tcp_retransmits counter\n")
        retrans_table = b.get_table("retransmit_count")
        if not retrans_table:
            f.write('iscsi_tcp_retransmits{port="3260"} 0\n')
        else:
            for k, v in retrans_table.items():
                f.write(f'iscsi_tcp_retransmits{{port="{k.value}"}} {v.value}\n')

load_state()
print("Previous state loaded.")
print("Tracking iSCSI block I/O... Press Ctrl+C to stop.")
print(f"Monitoring devices: {[f'{m}:{n}' for (m, n) in MONITORED_DEVICES]}")

try:
    while True:
        start = time.time()
        while time.time() - start < 1:
            b.perf_buffer_poll(timeout=100)
        write_prometheus_file()
except KeyboardInterrupt:
    save_state()
    print("\nStopped and state saved.")

