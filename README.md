# MATSCRIPT
A script interpreter for matrix manipulations, such as:
* Convert matrix files to a different format
* Merge matrices
* Transpose matrices
* Get matrix statistics

# Scripting Syntax
A script file is a ASCII text file containing a series of commands lines that are executed by the MATSCRIPT-program line by line. Each line begins with a command, followed by a sequence of key=value pairs, separated by semicolons. Any lines that begin with the asterisk character (*) are considered comments and are ignored by the MATSCRIPT-program. The scritp file name is passed as an command line argument to the MATSCRIPT-program.

# Dependencies
MATSCRIPT uses the following libraries, that have been added as submodules:
* https://github.com/transportmodelling/Utils
* https://github.com/transportmodelling/matio 
