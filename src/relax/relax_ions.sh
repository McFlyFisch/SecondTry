#! /usr/bin/bash

# DESCRIPTION
# This script takes a given structure and relaxes its ionic positions, optionally also the cell shape, until
# there are no more ionic steps performed.

# WISHLIST
# - more cookies
# - More error handling(esp. for missing files)
# - recognize when something weird happens (e.g phase transition)
# - implement what people online say are the best parameters fo monitor during relaxation
# - handle WARNING: random wavefunctions but no delay for mixing, default for NELMDL
# - Better emergency break that MAX_ITR, e.g. based on actual change in total energy (especially needed to
#   react when EDIFFG set too small)
# - Implement test to find best POTIM as described on the IBRION vasp wiki page
# - repeated creation of KPOINTS in forcerelax loop is unnnessessary
# - Import KPOINT creation form somewhere else
# - Add final energy decrease compared to initial number in job.sh ouput
# - automatic POTCAR assembly
# - Less dependencies on current woring directory environment, put more in ~/share
# - Better cleanup afterwards
# - Make INCAr sensitive to number of cores used

# DEPENDENCIES
# Files expected in current working directory
# - POTCAR
# - POSCAR
# Other dependencis in other directories
# - KPOINTS.temp in /home/su37jov/share/
# - write_kpts.py in /home/su37jov/share/
# - INCAR_forcerelax in /home/su37jov/src/relax

# INPUT
ENCUT=$1
KPTS_N=$2
MAX_REL=$3		# Stop if one step takes more than this many relaxation steps
EDIFFG=$4		# e.g. -1E-02 for better accuracy in final run
TIME=$5

#------------------------------------------------------------------------------------------------------------------
echo "--- Ionic Relaxation started"
date
echo

# Initial setup
echo "Initial setup"
echo "ENCUT: $ENCUT; KPTS_N: $KPTS_N"
echo "Break condition, MAX_REL: $MAX_REL"
echo "EDIFFG: $EDIFFG"

# Function to write KPOINTS.
# Input argument: KPTS_N
write_KPOINTS (){
   echo -n "write_KPOINTS(KPTS_N=$1) ... "
   local LAT_FAC=` head -2 POSCAR | tail -1 `
   local A1=` head -3 POSCAR | tail -1 | sed 's/\s\s*/ /g' `
   local A2=` head -4 POSCAR | tail -1 | sed 's/\s\s*/ /g' `
   local A3=` head -5 POSCAR | tail -1 | sed 's/\s\s*/ /g' `
   local K_VALUES=$( echo $1 $LAT_FAC $A1 $A2 $A3 | python /home/su37jov/share/write_kpts.py )
   local k1=$( echo $K_VALUES | cut -d ',' -f 1 )
   local k2=$( echo $K_VALUES | cut -d ',' -f 2 )
   local k3=$( echo $K_VALUES | cut -d ',' -f 3 )
   sed "s/k1_k2_k3/$k1 $k2 $k3/g" /home/su37jov/share/KPOINTS.temp > ./KPOINTS
   echo "done: (k1,k2,k3) = ($k1,$k2,$k3)"
}

# Setup extra folder within current working directory and copy necessary files in there
mkdir ./ionic_relaxation #2DO: Check if already exist, react accordingly
cd ./ionic_relaxation
cp ../POSCAR ./POSCAR
cp ../POTCAR ./

# Set INCAR as wanted and create KPOINTS file
sed -r "s/ENCUT\s*=\s*[0-9]+/ENCUT   =  $ENCUT/" /home/su37jov/src/relax/INCAR_forcerelax > ./INCAR
#2DO: Set $EDIFFG
write_KPOINTS $KPTS_N

# Enter relaxation loop
FULLY_RELAXED=false
N_REL=0
touch OUTCAR_full
echo -n "Ionic steps: "
until $FULLY_RELAXED
do
	# Run VASP, output to ./vasp_output
	mpirun /home/su37jov/VASP/VASP.5.4.4_FTW_2019_modifiedTransmatrix/vasp.5.4.4/build/std/vasp >> ./vasp_output
	echo >> ./vasp_output
	echo -n '________________________________________________________________________' >> ./vasp_output
	echo '___________________________' >> ./vasp_output # Too long to fit in one line...
	echo >> ./vasp_output
	echo >> ./OUTCAR
        echo -n '________________________________________________________________________' >> ./OUTCAR
        echo '___________________________' >> ./OUTCAR # Too long to fit in one line...
        echo >> ./OUTCAR
	cat OUTCAR_full OUTCAR > OUTCAR_full.temp; mv OUTCAR_full.temp OUTCAR_full

	# Check how many ionic steps there were, consider stucture relaxed if there was only 1. Else, start over.
	ION_STPS=`awk '/F=/ {print $1}' OSZICAR | tail -n 1`
	echo -n "$ION_STPS "
	if [ $ION_STPS -eq 1 ]
	then
		echo; echo "Done. Structure relaxed after $N_REL relaxation calls."
		FULLY_RELAXED=true
	else
		mv CONTCAR POSCAR
	fi
	
	# Count loop, check if it takes too long. If so, stop
	N_REL=$(( N_REL + 1 ))
	if [ $N_REL -eq $MAX_REL ]
        then
                echo; echo "WARNING: Relaxation takes suspiciously long!"
                FULLY_RELAXED=true
	fi
	done

date
echo "--- Relaxation Script ended"
