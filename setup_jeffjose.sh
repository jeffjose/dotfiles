#!/bin/bash
#
# Jan 16, 2021

sudo apt install -y tcsh

useradd -s /bin/tcsh -m jeffjose
usermod -aG sudo jeffjose
passwd jeffjose
