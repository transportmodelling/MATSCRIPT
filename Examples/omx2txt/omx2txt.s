* Converts the IVT and TRANSFERS matrices from the sample input file from omx to text format.
* No support for zone numbers stored along with the matrix values in the omx file.
* omx-labels are casesensitive!
init size=485
read file=input\example.omx; format=omx; id=1
matrix file=1; label=IVT; id=1
matrix file=1; label=TRANSFERS; id=2
write matrices=1,2; file=output\example.txt; format=txt; delim=tab
write matrices=1,2; file=output\example.csv; format=txt; delim=comma
