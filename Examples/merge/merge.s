* Calculates result = 0.5+2*A+B+C
* Where: A is the first matrix from the random1.csv file;
*        B is the first matrix from the random2.dat file
*        C is the second matrix from the random2.dat file
init size=10
read file=input\random1.csv; format=txt; delim=comma; header=false; id=1
read file=input\random2.dat; format=txt; delim=tab; header=true; id=2
const  value=0.5; id=1
* Select matrix A by index (no header available)
matrix file=1; index=1; id=2
* Select matrix B by label
matrix file=2; label=B; id=3
* Select matrix C by label
matrix file=2; label=C; id=4
* Calculate 2*A
scale matrix=2; factor=2; id=5
* Calculate result
merge matrices=1,3,4,5; tag=result; id=6
write matrices=6; file=output\merged.txt; format=txt; delim=tab; header=false
write matrices=6; file=output\merged.omx; format=omx
write matrices=6; file=output\merged.mtp; format=mtp; prec=4
