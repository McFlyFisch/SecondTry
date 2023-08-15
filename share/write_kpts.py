# Script to compute ideal partitions for smallest possible incremental increase in irr. k_poits,
# while also staying "truest" to N1:N2:N3 = 1/|a1|:1/|a2|:1/|a3|
# Solution: N_i = (N1+N2+N3) * a_j * a_k / ( a1*a2 + a2*a3 + a3*a1 ) for all i != j != k
#
# By me, Nico Fischer, Jan 3 2023, used for shell script converge.sh

import sys

# Get raw data from function call
input_line = sys.stdin.readline().split()
N_KPTS = int(input_line[0])
LAT_FAC = float(input_line[1])

# norms of lattice vectors, |a| = factor*sqrt(ax^2+ay^2+az^2)
a1 = LAT_FAC*(float(input_line[2])**2 + float(input_line[3])**2 + float(input_line[ 4])**2)**0.5
a2 = LAT_FAC*(float(input_line[5])**2 + float(input_line[6])**2 + float(input_line[ 7])**2)**0.5
a3 = LAT_FAC*(float(input_line[8])**2 + float(input_line[9])**2 + float(input_line[10])**2)**0.5

# compute partitions (see formula in head; round(3.49)=3.0, round(3.5)=4.0)
n1 = round( N_KPTS * a2 * a3 / ( a1*a2 + a2*a3 + a3*a1 ) )
n2 = round( N_KPTS * a3 * a1 / ( a1*a2 + a2*a3 + a3*a1 ) )
n3 = round( N_KPTS * a1 * a2 / ( a1*a2 + a2*a3 + a3*a1 ) )

# VASP needs partitions to be integers and at least >= 1
n1 = max(1,int(n1))
n2 = max(1,int(n2))
n3 = max(1,int(n3))

# return via stdout
print(str(n1) + "," + str(n2) + "," + str(n3))
