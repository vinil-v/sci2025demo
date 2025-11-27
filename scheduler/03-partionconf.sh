#!/bin/sh
# This script builds a partition configuration for D4sv5 based on the compute node details
# This is for Demonstration purposes only. Please modify as per your requirements.
# Author : Vinil Vadakkepurakkal
# Date : 26/11/2025
echo "PartitionName=onprem Nodes=compute1 State=UP Default=YES" >> /etc/slurm/azure.conf
echo "NodeName=compute1 CPUs=4 Boards=1 SocketsPerBoard=1 CoresPerSocket=2 ThreadsPerCore=2 RealMemory=15989" >> /etc/slurm/azure.conf
#restart slurm to apply changes
scontrol reconfigure