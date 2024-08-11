init size=10
read file=input\random1.csv; format=txt; delim=comma; header=false; id=1; ids=1
transpose matrix=1; id=2; tag=Transposed
write matrices=2; file=output\transposed.csv; format=txt; delim=comma
