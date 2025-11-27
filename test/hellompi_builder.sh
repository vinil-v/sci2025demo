#!/bin/sh

cat << 'EOF' > hello_mpi.c
#include <mpi.h>
#include <stdio.h>

int main(int argc, char** argv) {
    MPI_Init(&argc, &argv);

    int world_rank, world_size;
    MPI_Comm_rank(MPI_COMM_WORLD, &world_rank);
    MPI_Comm_size(MPI_COMM_WORLD, &world_size);

    printf("Hello from rank %d of %d\n", world_rank, world_size);

    MPI_Finalize();
    return 0;
}
EOF
module load mpi/impi-2021
mpicc -o hello_mpi hello_mpi.c