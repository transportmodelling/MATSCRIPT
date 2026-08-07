# MATSCRIPT
A script interpreter for matrix manipulations, such as:
* Convert matrix files to a different format
* Scale matrices
* Merge matrices
* Transpose matrices
* Get matrix statistics
* Compare matrices

# Scripting Syntax
A script file is an ASCII text file containing a series of commands that are executed by the MATSCRIPT-program. A command starts at the first position of a line (without indentation), and takes its arguments as key: value pairs on the subsequent lines, indented by at least one space or tab:

```
read
  file: input\example.omx
  format: omx
  id: 1
```

Alternatively (or additionally), the arguments can be provided on the command line itself, as a sequence of key=value pairs separated by semicolons (`read file=input\example.omx; format=omx; id=1`). When both styles are combined and the same key is provided both ways, the value on the command line takes precedence.

Empty lines and lines that begin with an asterisk (*) or hash (#) character (comments) are ignored by the MATSCRIPT-program; they never end the argument lines of a command. The script file name is passed as a command line argument to the MATSCRIPT-program.

The following commands are supported:

**init** <br>
The init-command initializes the script interpreter and should be the first command in any MATSCRIPT-script. A script may contain multiple init-commands: each init-command starts a new run, and a run is executed as soon as the next init-command (or the end of the script file) is reached. It takes the following key-value pairs as an argument:
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
   <tr>
    <td>delim</td>
    <td>The character enclosing parameter names (optional, default equals %; see the <a href="#parametrization">Parametrization</a> section). The delimiter takes effect from the next command onwards</td>
 </tbody>
</table>

**include** <br>
The include-command inserts the commands of another script file, as if they were part of the including script file. Included script files may include other script files themselves. In addition to the file-key, any other keys define parameters that apply to the included script file only (see the [Parametrization](#parametrization) section). It takes the following key-value pairs as an argument:
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
    <td>Name of the script file to be included</td>
   <tr>
    <td>&lt;name&gt;</td>
    <td>Value of parameter &lt;name&gt;, applying to the included script file only (optional)</td>
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
    <td>File identifier that can be used to reference the input file in subsequent command lines (optional)</td>
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
    <td>Matrix label to be used when writing the matrix to a matrix output file (optional)</td>
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
    <td>Matrix label to be used when writing the transposed matrix to a matrix output file (optional)</td>
 </tbody>
</table>

**const** <br>
The const-command defines a matrix with constant values. It takes the following key-value pairs as an argument:
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
    <td>Matrix identifier that can be used to reference the matrix in subsequent command lines</td>
   <tr>
    <td>value</td>
    <td>The value of the matrix cells. Alternatively, two comma separated values can be provided: the value of the diagonal cells, followed by the value of the off-diagonal cells</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the matrix to a matrix output file (optional)</td>
 </tbody>
</table>

**scale** <br>
The scale-command multiplies all matrix cells with a fixed factor. It takes the following key-value pairs as an argument:
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
    <td>Matrix identifier that can be used to reference the scaled matrix in subsequent command lines</td>
   <tr>
    <td>matrix</td>
    <td>Matrix identifier of the matrix being scaled</td>
   <tr>
    <td>factor</td>
    <td>The multiplication factor applied to all matrix cells</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the scaled matrix to a matrix output file (optional)</td>
 </tbody>
</table>

**round** <br>
The round-command rounds all matrix cells. It takes the following key-value pairs as an argument:
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
    <td>Matrix identifier that can be used to reference the rounded matrix in subsequent command lines</td>
   <tr>
    <td>matrix</td>
    <td>Matrix identifier of the matrix to be rounded</td>
   <tr>
    <td>digits</td>
    <td>The number of decimals places to round to (optional, default equals 0)</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the rounded matrix to a matrix output file (optional)</td>
 </tbody>
</table>

**merge** <br>
The merge-command calculates the sum of some matrices. It takes the following key-value pairs as an argument:
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
    <td>Matrix identifier that can be used to reference the merged matrix in subsequent command lines</td>
   <tr>
    <td>matrices</td>
    <td>Comma separated list of the matrix identifiers of the matrices that will be merged</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the merged matrix to a matrix output file (optional)</td>
 </tbody>
</table>

**multiply** <br>
The multiply-command calculates the cell-wise product of some matrices. It takes the following key-value pairs as an argument:
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
    <td>Matrix identifier that can be used to reference the product matrix in subsequent command lines</td>
   <tr>
    <td>matrices</td>
    <td>Comma separated list of the matrix identifiers of the matrices that will be multiplied</td>
   <tr>
    <td>tag</td>
    <td>Matrix label to be used when writing the product matrix to a matrix output file (optional)</td>
 </tbody>
</table>

**write** <br>
The write-command writes matrices to a matrix output file. In addition to the key-value pairs [specifying the file name and file format](https://github.com/transportmodelling/matio/wiki/File-specification), it takes the following key-value pairs as an argument:
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
    <td>matrices</td>
    <td>Comma separated list of matrix identifiers of the matrices that are written to the output file</td>
 </tbody>
</table>

**totals** <br>
The totals command writes a file containing row and column totals. It takes the following key-value pairs as an argument:
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
    <td>matrices</td>
    <td>Comma separated list of the matrices to include in the row and column totals</td>
   <tr>
    <td>file</td>
    <td>Name of the output file that contains three columns (row/column, row total, column total)</td>
   <tr>
    <td>delim</td>
    <td>Delimiter (comma/tab/semicolon/space) used to separate the columns in the output file (optional, default equals to tab-separated)</td>
 </tbody>
</table>

**stats** <br>
The stats command writes matrix statistics to the console. If a log file is specified in the init command, the matrix statistics are also written to the log file. It takes the following key-value pairs as an argument:
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
    <td>rows</td>
    <td>Comma separated list of rows to include in the statistics (optional, default equals to all rows)</td>
   <tr>
    <td>columns</td>
    <td>Comma separated list of columns to include in the statistics (optional, default equals to all columns)</td>
   <tr>
    <td>matrices</td>
    <td>Comma separated list of matrix identifiers of the matrices to include in the statistics</td>
 </tbody>
</table>

**compare** <br>
The compare command writes the sum of absolute differences between two matrices to the console. If a log file is specified in the init command, the sum of absolute differences is also written to the log file. It takes the following key-value pairs as an argument:
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
    <td>rows</td>
    <td>Comma separated list of rows to include in the comparison (optional, default equals to all rows)</td>
   <tr>
    <td>columns</td>
    <td>Comma separated list of columns to include in the comparison (optional, default equals to all columns)</td>
   <tr>
    <td>matrices</td>
    <td>Matrix identifiers of the two matrices to be compared, separated by a comma</td>
 </tbody>
</table>

# Parametrization
Scripts can be parameterized by passing name=value pairs on the command line, after the script file name:

```
MATSCRIPT skim.s purp=5
```

Within the argument values of a command, parameter names enclosed in percent-characters are replaced by the parameter values. With purp equal to 5, the command line above interprets the script command:

```
read
  file: skim_%purp%.omx
  ids: 1
```

as:

```
read
  file: skim_5.omx
  ids: 1
```

Parameter names are case insensitive, and all occurrences of a placeholder are replaced. The replacement applies to the argument values only; commands and keys are left untouched. Placeholders of parameters that have not been specified are left unchanged.

When the percent-character conflicts with the script content, another delimiter can be selected with the delim-key of the init-command. As the init-command and its arguments have already been read when the delim-value is interpreted, the new delimiter takes effect from the next command onwards. The delimiter applies up to the next init-command, which restores the default delimiter unless it specifies a delim-value itself.

In addition to the command line, the include-command can specify parameters as well. Any keys other than the file-key define parameters that apply to the included script file (and the files it includes) only. When the same parameter name is specified at several levels, the innermost include takes precedence within the included file. As the replacement is applied to the values of the include-command itself as well (using the parameters valid in the including file), parameter values can be passed on to nested includes.

The example below reads work trips into matrix 1 and other trips into matrix 2, by including the same script file twice with different parameter values:

main.s:
```
init
  size: 100

include
  file: demand.s
  purp: work
  id: 1

include
  file: demand.s
  purp: other
  id: 2
```

demand.s:
```
read
  file: %purp%_trips.omx
  ids: %id%
```

# Dependencies
MATSCRIPT uses the following libraries, that have been added as submodules:
* https://github.com/transportmodelling/Utils
* https://github.com/transportmodelling/matio

To use [hdf5](https://www.hdfgroup.org/) based matrix formats (such as [omx](https://github.com/osPlanning/omx)), the hdf5.dll must accompany the MATSCRIPT executable.
