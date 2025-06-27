# Research on Implementation Approaches for iSCSI Monitoring

## Setting Up Monitoring for iSCSI

To monitor iSCSI kernel interactions:

1. **Identify Relevant Kernel Functions**  
   Determine which kernel functions handle iSCSI operations. This might include functions related to the SCSI subsystem and network stack.

2. **Write eBPF Programs**  
   Using **BCC** or **bpftrace**, write eBPF programs that attach to these kernel functions to trace events and collect metrics.  
   Sources:  
   - GitHub  
   - BetterStack  

3. **Export Metrics**  
   Utilize **ebpf_exporter** to export collected metrics to **Prometheus**, enabling visualization and alerting.  
   Sources:  
   - [srodi.com](https://srodi.com)  
   - GitHub  

4. **Visualize Data**  
   Use **Grafana** or **Netdata** to create dashboards that display the metrics, aiding in monitoring and troubleshooting.

---

## Comparison of Tools

| Tool                  | Pros                                              | Best Use Case                             |
|-----------------------|---------------------------------------------------|-------------------------------------------|
| **BCC Python scripts**| Flexible, easier for exporting custom metrics     | Custom metric collection and scripting    |
| **bpftrace scripts**  | Quick for prototyping, low-volume metrics         | Debugging and real-time kernel tracing    |
| **CO-RE C eBPF + ebpf_exporter** | Production-grade, Prometheus-ready       | High-performance, persistent monitoring   |

---

## Tools Overview

### 1. ebpf_exporter (Cilium)
- **Purpose**: Exports eBPF map data as Prometheus metrics.
- **Workflow**: 
  - Write and compile eBPF C programs.
  - Configure metric mapping in `ebpf_exporter.yaml`.
  - Run the exporter.
- **Prometheus Integration**: Native `/metrics` endpoint.

📎 [GitHub: cloudflare/ebpf_exporter](https://github.com/cloudflare/ebpf_exporter)

---

### 2. BCC with Node Exporter (Textfile Collector)
- **Purpose**: Custom metric gathering via Python-based eBPF scripts.
- **Use Case**: Lightweight scripts for specific kernel events like iSCSI reads/writes.
- **Workflow**:
  - Attach BCC to kernel probes.
  - Write output to `.prom` files in Node Exporter’s `textfile_collector` directory.
- **Prometheus Integration**: Indirect (via textfile collector).

---

### 3. bpftrace
- **Purpose**: Interactive tracing for debugging or short-term inspection.
- **Use Case**: Real-time kernel tracing and observation.
- **Workflow**:
  - Use high-level scripts or one-liners to attach to iSCSI-related functions.
- **Prometheus Integration**: Not native; export requires custom bridging.

---

