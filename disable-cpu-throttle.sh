#!/bin/sh
# from https://bugzilla.redhat.com/show_bug.cgi?id=924570#c34
echo 1 | sudo tee /sys/devices/system/cpu/intel_pstate/no_turbo
