#!/usr/bin/env bash
#
#
df -h

sudo pvresize /dev/sda3
sudo lvresie -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv
sudo resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv

df -h
