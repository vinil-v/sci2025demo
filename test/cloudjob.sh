#!/bin/bash
#SBATCH --job-name=my_cloudjob            # Job name
#SBATCH --output=output_%j.txt       # Standard output (%j = job ID)
#SBATCH --error=error_%j.txt         # Standard error
#SBATCH --partition=oncloudhpc         # Partition/queue name
#SBATCH --nodes=2                  # Number of nodes

echo "Job started on $(date)"

# Load modules if needed
 module load mpi/impi-2021

# Run your application
scontrol show hostname $SLURM_JOB_NODELIST | sort -u > nodefile-$SLURM_JOB_ID
mpirun -np 2 --hostfile nodefile-$SLURM_JOB_ID -genv I_MPI_DEBUG=5 -genv I_MPI_HYDRA_IFACE=ib0 -genv I_MPI_FABRICS=shm:ofi -genv UCX_TLS=dc,xpmem,self IMB-MPI1 PingPong

echo "Job finished on $(date)"