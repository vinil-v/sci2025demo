#!/bin/bash
#SBATCH --job-name=mpi-test
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --time=00:05:00
#SBATCH --partition=onprem   # or oncloudhpc etc.

echo "Running on host: $(hostname)"
echo "SLURM_NTASKS = $SLURM_NTASKS"
module load mpi/impi-2021

mpirun -np $SLURM_NTASKS ./hello_mpi
echo "Job completed."