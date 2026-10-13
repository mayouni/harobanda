#!/usr/bin/env bash
# TIM-1: read the kernel's own rules for a deadline task's root domain and a
# cpuset partition, from the extracted source tree -- into a file, because WSL
# output through the PowerShell tool is mangled. Not a gate: a reading.
set -u
K=$(dirname "$(find "$HOME/harb-kernel/src" -maxdepth 4 -path '*/kernel/Kconfig.preempt' 2>/dev/null | head -1)")/..
OUT="/mnt/d/GitHub/harobanda/zig-out/wsl/deadline_kernel_read.txt"
mkdir -p "$(dirname "$OUT")"
{
  echo "== tree: $K"
  [ -d "$K" ] || { echo "no tree at $K"; ls "$HOME/harb-kernel" 2>/dev/null; ls "$HOME/harb-kernel/src" 2>/dev/null; }
  echo "== init/Kconfig: CPUSETS and CPU_ISOLATION"
  grep -n -A4 '^config CPUSETS' "$K/init/Kconfig"
  grep -n -A4 '^config CPU_ISOLATION' "$K/init/Kconfig"
  echo "== kernel/Kconfig.preempt: the model choice"
  grep -n -B2 -A12 '^config PREEMPT_RT' "$K/kernel/Kconfig.preempt"
  grep -n -B1 -A3 '^choice' "$K/kernel/Kconfig.preempt"
  echo "== the deadline span check (syscalls.c or core.c)"
  grep -n -B6 -A6 'cpumask_subset(span, p->cpus_ptr)' "$K/kernel/sched/syscalls.c" "$K/kernel/sched/core.c" 2>/dev/null
  echo "== def_root_domain and detach_destroy_domains (topology.c)"
  grep -n -B3 -A8 '^static void detach_destroy_domains' "$K/kernel/sched/topology.c"
  grep -n 'def_root_domain' "$K/kernel/sched/topology.c"
  echo "== to_ratio and the overflow check (deadline.c / sched.h)"
  grep -n -A8 '^unsigned long to_ratio' "$K/kernel/sched/core.c" "$K/kernel/sched/deadline.c" 2>/dev/null
  grep -n -B2 -A8 '__dl_overflow(struct dl_bw' "$K/kernel/sched/sched.h"
  grep -n -B4 -A30 '^int sched_dl_overflow' "$K/kernel/sched/deadline.c"
  echo "== __checkparam_dl"
  grep -n -A40 '^bool __checkparam_dl' "$K/kernel/sched/deadline.c"
  echo "== cpuset: partition write path and the top cpuset's tasks"
  grep -n 'CONFIG_CPU_ISOLATION\|housekeeping' "$K/kernel/cgroup/cpuset.c" | head -20
  grep -n -B2 -A24 '^static void update_tasks_cpumask' "$K/kernel/cgroup/cpuset.c"
  grep -n -A6 'PRS_ROOT\b.*=\|PRS_ISOLATED\b.*=' "$K/kernel/cgroup/cpuset.c" | head -30
  grep -n -B3 -A40 '^static int update_prstate' "$K/kernel/cgroup/cpuset.c" | head -90
  echo "== sched_fork: the reset-on-fork rule for a deadline parent"
  grep -n -B4 -A24 'p->sched_reset_on_fork' "$K/kernel/sched/core.c" | sed -n '1,80p'
  echo "== the kernel's own bounds on a period, and to_ratio"
  grep -n 'sysctl_sched_dl_period_m\(ax\|in\) =' "$K/kernel/sched/deadline.c"
  grep -rn -A6 'to_ratio(u64 period, u64 runtime)' "$K/kernel/sched/" | head -12
  grep -n 'define BW_SHIFT\|define DL_SCALE' "$K/kernel/sched/sched.h"
  echo "== the fair tasks' own deadline server (6.12): its share, and where it is accounted"
  grep -n -A12 '^void fair_server_init' "$K/kernel/sched/fair.c"
  grep -n -A16 '^void dl_server_init' "$K/kernel/sched/deadline.c"
  grep -n -B2 -A10 '^void dl_server_start' "$K/kernel/sched/deadline.c" | grep -n 'dl_runtime\|dl_period\|NSEC'
  grep -rn 'NSEC_PER_MSEC' "$K/kernel/sched/fair.c" | grep -i 'server\|runtime\|period' | head
  grep -n -A28 '^int dl_server_apply_params' "$K/kernel/sched/deadline.c" | head -40
  grep -n -B2 -A16 '^void __dl_server_attach_root' "$K/kernel/sched/deadline.c"
  grep -n -B3 -A12 '^static inline int dl_bw_cpus' "$K/kernel/sched/deadline.c"
  echo "== generate_sched_domains: isolated cpus"
  grep -n 'isolated_cpus\|isolcpus\|HK_TYPE_DOMAIN' "$K/kernel/cgroup/cpuset.c" | head -40
} > "$OUT" 2>&1
echo "wrote $OUT"
