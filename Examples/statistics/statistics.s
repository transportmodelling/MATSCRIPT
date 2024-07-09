* Calculates matrix totals for the input matrices of the merge example
init size=10; log=Output\statistics.log
read file=input\random1.csv; format=txt; delim=comma; header=false; id=1
read file=input\random2.dat; format=txt; delim=tab; header=true; id=2
matrix file=1; index=1; id=1
matrix file=2; index=1; id=2
matrix file=2; index=2; id=3
stats matrices=1
stats matrices=1; Rows=1
stats matrices=2
stats matrices=2; Columns=1
stats matrices=3
stats matrices=1-3
