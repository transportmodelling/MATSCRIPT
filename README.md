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
    <td>log</td>
    <td>Log file name (optional)</td>
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
    <td>Comma separated list of matrix identifiers that can be used to reference matrices (contained in the input file) in subsequent command lines (optional)</td>
 </tbody>
</table>

# Dependencies
MATSCRIPT uses the following libraries, that have been added as submodules:
* https://github.com/transportmodelling/Utils
* https://github.com/transportmodelling/matio 
