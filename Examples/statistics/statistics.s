* Calculates statistics for the input matrices of the merge example
init size=10; log=Output\statistics.log
read file=input\random1.csv; format=txt; delim=comma; header=false; ids=1
read file=input\random2.dat; format=txt; delim=tab; header=true; ids=2,3
stats matrices=1
stats matrices=1; Rows=1
stats matrices=2
stats matrices=2; Columns=1
stats matrices=3
stats matrices=1-3

* Compare matrices 2 and 3
compare matrices=2,3

* Save row and column totals matrix 1
totals file=output\totals.csv; matrices=1; delim=comma
