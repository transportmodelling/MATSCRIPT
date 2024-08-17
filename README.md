# MATSCRIPT
A script interpreter for matrix manipulations, such as:
* Convert matrix files to a different format
* Merge matrices
* Transpose matrices
* Get matrix statistics

# Scripting Syntax
A script file is a ASCII text file containing a series of commands lines that are executed by the MATSCRIPT-program line by line. Each line begins with a command, followed by a sequence of key=value pairs, separated by semicolons. Any lines that begin with the asterisk character (*) are considered comments and are ignored by the MATSCRIPT-program. The scritp file name is passed as an command line argument to the MATSCRIPT-program.

The following commands are supported:

**init** <br>
The init-command initializes the script interpreter and should be the first command in any MATSCRIPT-script. It takes the following key-value pairs as an argument:
<table border="1">
 <col style="width:10%">
 <col style="width:90%">
 <thead>
  <tr>
    <td><b>Key</b></td>
    <td><b>Value</b></td>
   </tr>
 </thead>
 <tbody>
   <tr>
    <td>size</td>
    <td>Size of the matrices being processed in the script</td>
   <tr>
    <td>round</td>
    <td>Rounding threshold. When writing matrices to file, all matrix cells with an absolute value less than the threshold get rounded to zero (optional, default equals 0)</td>
   <tr>
    <td>row</td>
    <td>Header for the Row-column used in text output files (optional, default equals "Row")</td>
   <tr>
    <td>column</td>
    <td>Header for the Column-column used in text output files (optional, default equals "Column")</td>
   <tr>
    <td>log</td>
    <td>Log file name (optional, default no logging to file)</td>
 </tbody>
</table>

**read** <br>
The read-command reads matrices from a matrix input file. In addition to the key-value pairs [specifying the file name and file format](https://github.com/transportmodelling/matio/wiki/File-specification), it takes the following key-value pairs as an argument:
<table border="1">
 <col style="width:10%">
 <col style="width:90%">
 <thead>
  <tr>
    <td><b>Key</b></td>
    <td><b>Value</b></td>
   </tr>
 </thead>
 <tbody>
   <tr>
    <td>id</td>
    <td>File identifier that can be used to reference the input file in subsequent command lines</td>
   <tr>
    <td>ids</td>
    <td>Comma separated list of matrix identifiers that can be used to reference matrices (contained in the input file) in subsequent command lines. The index in the list of identifiers coincides with the index of the matrix in the matrix input file. This (optional) key can thus only be used in the case of index based matrix access. In the case of label based matrix access the matrix-command must be used to specify the matrices in a matrix input file</td>
 </tbody>
</table>

**matrix** <br>
The matrix-command specifies a matrix that is read from a matrix input file. It takes the following key-value pairs as an argument:
<table border="1">
 <col style="width:10%">
 <col style="width:90%">
 <thead>
  <tr>
    <td><b>Key</b></td>
    <td><b>Value</b></td>
   </tr>
 </thead>
 <tbody>
   <tr>
    <td>file</td>
    <td>File identifier of the matrix input file the matrix is read from</td>
   <tr>
    <td>index</td>
    <td>Index of the matrix within the matrix input file. This key cannot be used together with the label key</td>
   <tr>
    <td>label</td>
    <td>Label of the matrix to be read from the matrix input file. This key cannot be used together with the index key</td>
   <tr>
    <td>id</td>
    <td>Matrix identifier that can be used to reference the matrix in subsequent command lines</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the matrix to a matrix output file</td>
 </tbody>
</table>

**transpose** <br>
The transpose-command calculates the transposed of a matrix. It takes the following key-value pairs as an argument:
<table border="1">
 <col style="width:10%">
 <col style="width:90%">
 <thead>
  <tr>
    <td><b>Key</b></td>
    <td><b>Value</b></td>
   </tr>
 </thead>
 <tbody>
   <tr>
    <td>matrix</td>
    <td>Identifier of the matrix being transposed</td>
   <tr>
    <td>id</td>
    <td>Matrix identifier that can be used to reference the transposed matrix in subsequent command lines</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the transposed matrix to a matrix output file</td>
 </tbody>
</table>

# Dependencies
MATSCRIPT uses the following libraries, that have been added as submodules:
* https://github.com/transportmodelling/Utils
* https://github.com/transportmodelling/matio

To use [hdf5](https://www.hdfgroup.org/) based matrix formats (such as [omx](https://github.com/osPlanning/omx)), the hdf5.dll must accompany the MATSCRIPT executable.
