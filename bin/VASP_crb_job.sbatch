#! /usr/bin/env bash

#SBATCH --job-name=jXXXXcrb
#SBATCH --partition=b_test
#SBATCH --exclusive
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=24
#SBATCH --time=03:00:00
#SBATCH --output=%x.o%j
#SBATCH --mail-user=nico.fischer@uni-jena.de
#SBATCH --mail-type=ALL

module load compiler/intel/2019-Update3
module load mpi/intel/2019-Update3
module load libs/fftw/3.3.7-intel-2019
eval "$(/home/su37jov/anaconda3/bin/conda shell.bash hook)" # needed for bandstructure (pyprocar) and EoS fit
env > env.out

#if [ ! -e "flow.config" ]; then exit 1; fi

HOME=/beegfs/su37jov

$HOME/src/relax/relax_ions.sh 350 12 10 -1E-02
