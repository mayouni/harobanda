#!/bin/bash
# wsl_cleanup.sh -- list and end any QEMU or image run left behind in WSL
# (a closed terminal can leave a stopped QEMU waiting for a tty it lost).
ps -eo pid,stat,etime,cmd | grep -E 'qemu-system|os2_image|timeout 180' | grep -v grep || echo "nothing left running"
pkill -9 -f qemu-system 2>/dev/null && echo "qemu ended" || true
pkill -9 -f os2_image.sh 2>/dev/null && echo "image run ended" || true
