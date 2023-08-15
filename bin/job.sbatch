#! /usr/bin/bash

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

# 2023 Feb 16: Written and created by Nico Kawashima

# DESCRIPTION
# This script was intended to automatize various calculations on a given Material. Each component, though, is
# optional. So far, the (planned) functions are:
#  - VASP convergence test with respect to ENCUT and number of k-points
#  - Relaxation of internal parameters as well as unit cell shape and volume
#  - Computation of the bandstructure for further plotting

# WISHLIST
# - Converge wrt SIGMA (I think I read that somewhere...? Ask Claudia maybe.)
# - Allow for easier INPUT handling for bulk job starting (e.g. -c -r -b as command line options?)
# - Make a fake_VASP_run script that simulates VASP output for debugging purposes
# - When copying from scripts, check for required files; more error handling in general (over time?)
# - Write an even higher-order script that can call several of of this "job" scripts at once for sets of materials
# - Allow for another convergence test after relaxation.
# - Check generated results for size: Is there something bulky that could be cleaned up or zipped?
# - write_kpts.py seems to produce k1 k2 k3 that don't add up to KPTS_N, e.g. 24 -> 6 6 11
# - use pwd somewhere in the beginnin (if that works...)

# DEPENDENCIES
#SCRIPTS="/data115/fischer/Documents/scripts"
SCRIPTS="/home/su37jov/src"
#SCRIPTS="/beegfs/su37jov/scripts"

# INPUT [REQUIRED]
# - place POSCAR in current working directory
# - place POTCAR in current working directory (e.g. /beegfs/vasp/potcar/potpaw/pbe/?)
DO_CONVRGE=false  # whether to find ENCUT and KPOINTS for convergence of TOTEN
DO_RELXATN=false  # whether to relax internal parameters and unit cell
DO_BNDSTRC=false  # whether to compute bandstructure
# - Check job-name
# - Check partition
# - Check nodes
# - Check (run)time
# - Consider adding sth like #SBATCH --mem-per-cpu=5000

# INPUT [OPT. CONVERGE]
C_ENCUT_MIN=300
C_ENCUT_MAX=600
C_ENCUT_STP=50
C_KPTS_N_MIN=12   # don't start too low, to make step 1 return reasonable results!
C_KPTS_N_MAX=50
C_KPTS_N_STP=6
C_EDIF_EPS="0.001" # eV per atom. Recommend not to decrease too much, fluctuations!
C_MAX_ITR=50

# INPUT [OPT. RELAX]
R_ENCUT=0		# Manual ENCUT. If R_ENCUT=0 will fetch values from ./converge/results (must be present!)   
R_KPTS_N=0		# Manual KPTS_N. If R_KPTS_N=0 will fetch values from ./converge/results (must be present!)
R_LOW="0.96"		# smallest factor on scaling
R_HIGH="1.04"		# highest factoron scaling
R_N_MEASSURE=4		# numer of measurements in each direction ( total = 2 * R_N_MEASSURE + 1 )
R_MAX_REL=100		# Stop if one step takes more than this many relaxation steps
R_DO_RLX=true		# relax across LOW-HIGH range
R_DO_TET=true		# Compute energies accurately via tetrahedral method
R_DO_FIT=true		# Call fit_EoS.py to fit equation of state to volume_vs_energy.txt
R_DO_RLX_MIN=true	# relax at identified minimum

# INPUT [OPT. BANDSTRUC]
B_ENCUT=0         # Manual ENCUT. If B_ENCUT=0 will fetch values from ./converge/results (must be present!)   
B_KPTS_N=0        # Manual KPTS_N. If B_KPTS_N=0 will fetch values from ./converge/results (must be present!)
B_USE_RELAXED_POSCAR=true	# If true, checks if there is a relax/final/CONTCAR and copies it to POSCAR
B_GEN_PATH=true		# Generate path through B.zone. If false, expects KPOINTS_path in current wd!
B_COMPUTE_CHGCAR=true	# Compute CHGAR. If false, expects CHGCAR in current wd!
B_COMPUTE_PATH=true       # Compute along path through B.zone. If false... Why would you do that?!
B_NAME_TAR="bs_data.tar.gz"	# Name of final output archive
B_HYBRID=false	# Whether or not to use hybrid functionals for bandstructure computation (currently not implm.)
#-----------------------------------------------------------------------------------------------------------------
echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxx Script started xxxxxxxxxxxxxxxxxxxxxxxxxxxx"
date
echo "Script name: job.sh"
echo
if [ -s POSCAR ]; then echo -n "POSCAR detected; "; else echo; echo "ERROR: No POSCAR found!"; exit 1; fi 
if [ -s POTCAR ]; then echo "POTCAR detected"; else echo; echo "ERROR: No POTCAR found!"; exit 1; fi
echo
if $DO_CONVRGE
then
	echo "Convergence wanted -- will do!"
	if [ -d converge ]
	then
        	echo "WARNING: directory 'converge' already exists!"
		echo "Will rm everything and run anew."
		rm -rf converge converge.out
	fi
       	mkdir -v converge
	cp $SCRIPTS/converge/* ./converge/ # Somewhere, check for presence of all required files! (2Do)
	cp ./POSCAR ./converge/
       	cp ./POTCAR ./converge/
else
	echo "No convergence tests will be done."
fi
echo
if $DO_RELXATN
then
       	echo "Relaxation wanted -- will do!"
	if [ -d relax ]
        then
                echo "WARNING: directory 'relax' already exists!"
                echo "Will copy resources anew and continue as is."
	else
        	mkdir -v relax
        fi
        cp $SCRIPTS/relax/* ./relax/
        cp ./POSCAR ./relax/
        cp ./POTCAR ./relax/
else
       	echo "No relaxation will be done."
fi
echo
if $DO_BNDSTRC
then
       	echo "Bandstructure computation wanted -- will do!"
	if [ -d bandstruc ]
        then
                echo "WARNING: directory 'bandstruc' already exists!"
		echo "Will copy resources anew and continue as is."
        else
                mkdir -v bandstruc
	fi
        cp -r $SCRIPTS/bandstruc/* ./bandstruc/
        cp ./POSCAR ./bandstruc/
        cp ./POTCAR ./bandstruc/
else
       	echo "No bandstructure computation wanted."
fi
echo

#-----------------------------------------------------------------------------------------------------------------
if $DO_CONVRGE; then echo "------------------------- Do Convergence-Tests -------------------------"
	cd converge
	echo -n "Start script converge.sh ... "
	./converge.sh $C_ENCUT_MIN $C_ENCUT_MAX $C_ENCUT_STP $C_KPTS_N_MIN $C_KPTS_N_MAX $C_KPTS_N_STP $C_EDIF_EPS $C_MAX_ITR &> ../converge.out
	if [[ $? -ne 0 ]]
	then
    		echo; echo "ERROR: Something went wrong. Check converge.out"
		echo; echo ---- converge.out ----
		cat converge.out
    		exit 1
	else
		echo "done."
	fi
	cd ..
	echo "It took $( egrep -c '^[0-9]{1,}' ./converge/results ) iterations."
	ENCUT=$( awk '{print $1}' ./converge/results | tail -1 )
	KPTS_N=$( awk '{print $2}' ./converge/results | tail -1 )
	echo "Found parameters: ENCUT=$ENCUT, KPTS_N=$KPTS_N"
	echo
fi

#-----------------------------------------------------------------------------------------------------------------
if $DO_RELXATN; then echo "---------------------------- Do Relaxation -----------------------------"
	if [ $R_ENCUT -eq 0 ]
        then
                R_ENCUT=$( awk '{print $1}' ./converge/results | tail -1 )
        fi
        if [ $R_KPTS_N -eq 0 ]
        then
                R_KPTS_N=$( awk '{print $2}' ./converge/results | tail -1 )
        fi
	cd relax
        echo -n "Start script relax.sh ... "
        ./relax.sh $R_ENCUT $R_KPTS_N $R_LOW $R_HIGH $R_N_MEASSURE $R_MAX_REL $R_DO_RLX $R_DO_TET $R_DO_FIT $R_DO_RLX_MIN &> ../relax.out
        if [[ $? -ne 0 ]]
        then
                echo; echo "ERROR: Something went wrong. Check relax.out"
                echo; echo ---- relax.out ----
                cat relax.out
                exit 1
        else
                echo "done."
        fi
        cd ..
	echo "Relaxed structure can be found in relax/final/tetrahedral_run/ ."
	echo
fi

#-----------------------------------------------------------------------------------------------------------------
if $DO_BNDSTRC; then echo "------------------------- Comp. Bandstructure --------------------------"
	if [ $B_ENCUT -eq 0 ]
	then
		B_ENCUT=$( awk '{print $1}' ./converge/results | tail -1 )
	fi
	if [ $B_KPTS_N -eq 0 ]
        then
                B_KPTS_N=$( awk '{print $2}' ./converge/results | tail -1 )
        fi
	if $B_USE_RELAXED_POSCAR && [ -s relax/final/CONTCAR ]
	then
		cp -v relax/final/CONTCAR bandstruc/POSCAR
	fi
	cd bandstruc
	if $B_HYBRID
	then
		echo "Hybrid functional selected. Unfortunately not yet implemented... :("
	else
		echo -n "Start script compute_bandstruc_PBE.sh ... "
        	./comp_bandstruc_PBE.sh $B_ENCUT $B_KPTS_N $B_GEN_PATH $B_COMPUTE_CHGCAR $B_COMPUTE_PATH $B_NAME_TAR &> ../bandstruc.out
	        if [[ $? -ne 0 ]]
        	then
                	echo; echo "ERROR: Something went wrong. Check bandstruc.out"
        	        echo; echo ---- bandstruc.out ----
	                cat bandstruc.out
                	exit 1
        	else
                	echo "done."
        	fi
	fi
        cd ..
	echo "Files to plot bandstructure can be found in $B_NAME_TAR"
	echo
fi

#-----------------------------------------------------------------------------------------------------------------
date
echo "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx Script ended xxxxxxxxxxxxxxxxxxxxxxxxxxx"
