unit TestMATSCRIPT.Interpreter;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/MATSCRIPT
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, IOUtils, DUnitX.TestFramework, KeyVal, Parse, matio.hdf5, MatrixScript;

Type
  [TestFixture]
  TInterpreterTests = Class
  // Executes scripts on a 3x3 input matrix whose cell (i,j) equals 10*i+j, within
  // a temporary directory that serves as base directory for relative file names.
  private
    Const
      Size = 3;
      Tolerance = 1E-6;
    Var
      Directory: String;
      ErrorCount: Integer; // Error count of the last executed script
    Function FilePath(const FileName: String): String;
    Function InputValue(const Row,Column: Integer): Float64;
    Procedure WriteInputMatrix;
    Function InitCommand: TArray<String>;
    Function ReadCommand: TArray<String>;
    Function WriteCommand(const Matrix: Integer; const FileName: String): TArray<String>;
    Procedure Execute(const Lines: TArray<String>); overload;
    Procedure Execute(const Lines: TArray<String>; const [ref] Parameters: TKeyValuePairs); overload;
    Function ReadOutputMatrix(const FileName: String): TArray<TArray<Float64>>;
    Procedure AssertOutputMatrix(const FileName: String); overload;
    Procedure AssertOutputMatrix(const FileName: String; const Expected: TFunc<Integer,Integer,Float64>); overload;
    Function LogContains(const FileName,Line: String): Boolean;
  public
    [Setup] Procedure Setup;
    [TearDown] Procedure TearDown;

    // Matrix commands
    [Test] Procedure Write_InputMatrix_CopiesCells;
    [Test] Procedure Transpose_InputMatrix_SwapsRowsAndColumns;
    [Test] Procedure Scale_InputMatrix_MultipliesCells;
    [Test] Procedure Round_ScaledMatrix_RoundsCells;
    [Test] Procedure Merge_ConstantAndInput_AddsCells;
    [Test] Procedure Merge_InputAndTransposed_AddsCells;
    [Test] Procedure Multiply_InputAndTransposed_MultipliesCells;
    [Test] Procedure Transpose_MergedWithTransposed_SwapsRowsAndColumns;

    // Info commands
    [Test] Procedure Totals_InputMatrix_WritesRowAndColumnTotals;
    [Test] Procedure Stats_InputMatrix_LogsTotalAndDiagonal;
    [Test]
    [TestCase('Rows','rows,63')]
    [TestCase('Columns','columns,36')]
    Procedure Stats_TransposedSelection_SelectsTransposedCells(const Key: String; const Total: Integer);
    [Test] Procedure Compare_InputAndTransposed_LogsSumOfAbsoluteDifferences;
    [Test] Procedure Compare_TransposedSelection_LogsAndSelectsTransposedCells;

    // Script structure
    [Test] Procedure Init_TwoRuns_ExecutesBothRuns;
    [Test] Procedure Init_TwoRunsSameLog_LogsBothRuns;
    [Test] Procedure Init_ExistingLog_IsOverwritten;
    [Test] Procedure Parameter_InFileName_IsReplaced;

    // Errors
    [Test] Procedure Execute_ValidScript_CountsNoErrors;
    [Test] Procedure Execute_InvalidCommand_CountsError;
    [Test] Procedure Execute_MissingInputFile_CountsError;
    [Test] Procedure Execute_ErrorInFirstRun_ExecutesNextRun;
    [Test] Procedure Execute_ErrorInMiddleRun_SkipsItsRemainingCommands;
    [Test] Procedure Write_UnknownFormat_LogsNoMatrixWriter;
    [Test] Procedure Write_OmxWithoutDll_LogsDllNotFound;
    [Test] Procedure Read_OmxWithoutDll_LogsDllNotFound;
    [Test]
    [TestCase('Transpose','transpose id=2; matrix=2','|')]
    [TestCase('Scale','scale id=2; matrix=2; factor=2','|')]
    [TestCase('Round','round id=2; matrix=2','|')]
    [TestCase('Merge','merge id=2; matrices=1,2','|')]
    [TestCase('Multiply','multiply id=2; matrices=1,2','|')]
    Procedure Command_OwnIdAsSource_LogsInvalidMatrixId(const Command: String);
    [Test]
    [TestCase('Negative','-1')]
    [TestCase('TooLarge','16')]
    Procedure Round_InvalidDigits_LogsInvalidDigits(const Digits: String);
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TInterpreterTests.FilePath(const FileName: String): String;
begin
  Result := TPath.Combine(Directory,FileName);
end;

Function TInterpreterTests.InputValue(const Row,Column: Integer): Float64;
// Row and Column are zero based
begin
  Result := 10*(Row+1) + (Column+1);
end;

Procedure TInterpreterTests.WriteInputMatrix;
Var
  Lines: TArray<String>;
begin
  for var Row := 0 to Size-1 do
  for var Column := 0 to Size-1 do
  Lines := Lines + [(Row+1).ToString + ',' + (Column+1).ToString + ',' + InputValue(Row,Column).ToString];
  TFile.WriteAllLines(FilePath('input.csv'),Lines,TEncoding.ASCII);
end;

Function TInterpreterTests.InitCommand: TArray<String>;
begin
  Result := ['init','  size: ' + Size.ToString];
end;

Function TInterpreterTests.ReadCommand: TArray<String>;
// Reads the input matrix as matrix 1
begin
  Result := ['read','  file: input.csv','  format: txt','  delim: comma','  header: false','  id: 1','  ids: 1'];
end;

Function TInterpreterTests.WriteCommand(const Matrix: Integer; const FileName: String): TArray<String>;
begin
  Result := ['write','  matrices: ' + Matrix.ToString,'  file: ' + FileName,
             '  format: txt','  delim: comma','  header: false'];
end;

Procedure TInterpreterTests.Execute(const Lines: TArray<String>);
Var
  Parameters: TKeyValuePairs;
begin
  Execute(Lines,Parameters);
end;

Procedure TInterpreterTests.Execute(const Lines: TArray<String>; const [ref] Parameters: TKeyValuePairs);
begin
  var ScriptFileName := FilePath('script.s');
  TFile.WriteAllLines(ScriptFileName,Lines,TEncoding.ASCII);
  var Interpreter := TMatrixScriptInterpreter.Create;
  try
    Interpreter.Execute(ScriptFileName,Parameters);
    ErrorCount := Interpreter.ErrorCount;
  finally
    Interpreter.Free;
  end;
end;

Function TInterpreterTests.ReadOutputMatrix(const FileName: String): TArray<TArray<Float64>>;
// The text writer leaves out the cells that equal zero
begin
  Result := nil;
  SetLength(Result,Size,Size);
  for var Line in TFile.ReadAllLines(FilePath(FileName)) do
  begin
    var Parser := TStringParser.Create(Comma,Line);
    Result[Parser.Int[0]-1,Parser.Int[1]-1] := Parser.Float[2];
  end;
end;

Procedure TInterpreterTests.AssertOutputMatrix(const FileName: String);
// Asserts that the output matrix equals the input matrix
begin
  AssertOutputMatrix(FileName,Function(Row,Column: Integer): Float64
                              begin
                                Result := InputValue(Row,Column);
                              end);
end;

Procedure TInterpreterTests.AssertOutputMatrix(const FileName: String; const Expected: TFunc<Integer,Integer,Float64>);
begin
  var Values := ReadOutputMatrix(FileName);
  for var Row := 0 to Size-1 do
  for var Column := 0 to Size-1 do
  Assert.AreEqual(Expected(Row,Column),Values[Row,Column],Tolerance,
                  'Cell (' + (Row+1).ToString + ',' + (Column+1).ToString + ')');
end;

Function TInterpreterTests.LogContains(const FileName,Line: String): Boolean;
begin
  Result := TFile.ReadAllText(FilePath(FileName)).Contains(Line);
end;

Procedure TInterpreterTests.Setup;
begin
  Directory := TPath.Combine(TPath.GetTempPath,'TestMATSCRIPT' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(Directory);
  TKeyValuePairs.SetBaseDir(Directory);
  WriteInputMatrix;
end;

Procedure TInterpreterTests.TearDown;
begin
  TDirectory.Delete(Directory,true);
end;

Procedure TInterpreterTests.Write_InputMatrix_CopiesCells;
begin
  Execute(InitCommand + ReadCommand + WriteCommand(1,'output.csv'));
  AssertOutputMatrix('output.csv');
end;

Procedure TInterpreterTests.Transpose_InputMatrix_SwapsRowsAndColumns;
begin
  Execute(InitCommand + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          WriteCommand(2,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := InputValue(Column,Row);
                                  end);
end;

Procedure TInterpreterTests.Scale_InputMatrix_MultipliesCells;
begin
  Execute(InitCommand + ReadCommand +
          ['scale','  matrix: 1','  factor: 2','  id: 2'] +
          WriteCommand(2,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := 2*InputValue(Row,Column);
                                  end);
end;

Procedure TInterpreterTests.Round_ScaledMatrix_RoundsCells;
// Scaling by 0.1 yields i.1 to i.3 in row i, which round to i
begin
  Execute(InitCommand + ReadCommand +
          ['scale','  matrix: 1','  factor: 0.1','  id: 2'] +
          ['round','  matrix: 2','  id: 3'] +
          WriteCommand(3,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := Row+1;
                                  end);
end;

Procedure TInterpreterTests.Merge_ConstantAndInput_AddsCells;
begin
  Execute(InitCommand + ReadCommand +
          ['const','  value: 0.5','  id: 2'] +
          ['merge','  matrices: 1,2','  id: 3'] +
          WriteCommand(3,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := InputValue(Row,Column) + 0.5;
                                  end);
end;

Procedure TInterpreterTests.Merge_InputAndTransposed_AddsCells;
begin
  Execute(InitCommand + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['merge','  matrices: 1,2','  id: 3'] +
          WriteCommand(3,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := InputValue(Row,Column) + InputValue(Column,Row);
                                  end);
end;

Procedure TInterpreterTests.Multiply_InputAndTransposed_MultipliesCells;
begin
  Execute(InitCommand + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['multiply','  matrices: 1,2','  id: 3'] +
          WriteCommand(3,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := InputValue(Row,Column)*InputValue(Column,Row);
                                  end);
end;

Procedure TInterpreterTests.Transpose_MergedWithTransposed_SwapsRowsAndColumns;
// Matrix 4 equals A+2*A' and is held in memory. Writing its transposed requires
// a second memory matrix, which can only be filled once matrix 4 is complete.
begin
  Execute(InitCommand + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['scale','  matrix: 2','  factor: 2','  id: 3'] +
          ['merge','  matrices: 1,3','  id: 4'] +
          ['transpose','  matrix: 4','  id: 5'] +
          WriteCommand(5,'output.csv'));
  AssertOutputMatrix('output.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := InputValue(Column,Row) + 2*InputValue(Row,Column);
                                  end);
end;

Procedure TInterpreterTests.Totals_InputMatrix_WritesRowAndColumnTotals;
// Row i totals 30*i+6 and column j totals 60+3*j
begin
  Execute(InitCommand + ReadCommand + ['totals','  matrices: 1','  file: totals.txt']);
  var Lines := TFile.ReadAllLines(FilePath('totals.txt'));
  Assert.AreEqual<Integer>(Size,Length(Lines));
  for var Index := 0 to Size-1 do
  begin
    var Parser := TStringParser.Create(Tab,Lines[Index]);
    var RowTotal: Float64 := 30*(Index+1)+6;
    var ColumnTotal: Float64 := 60+3*(Index+1);
    Assert.AreEqual<Integer>(Index+1,Parser.Int[0]);
    Assert.AreEqual(RowTotal,Parser.Float[1],Tolerance);
    Assert.AreEqual(ColumnTotal,Parser.Float[2],Tolerance);
  end;
end;

Procedure TInterpreterTests.Stats_InputMatrix_LogsTotalAndDiagonal;
// The cells total 198 and the diagonal cells 11+22+33
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand + ['stats','  matrices: 1']);
  Assert.IsTrue(LogContains('run.log','Total: 198'),'Total');
  Assert.IsTrue(LogContains('run.log','Diagonal: 66'),'Diagonal');
end;

Procedure TInterpreterTests.Stats_TransposedSelection_SelectsTransposedCells(const Key: String; const Total: Integer);
// Row 1 of the transposed matrix holds 11, 21 and 31, column 1 holds 11, 12 and 13
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['stats','  matrices: 2','  ' + Key + ': 1']);
  Assert.IsTrue(LogContains('run.log','Total: ' + Total.ToString),TFile.ReadAllText(FilePath('run.log')));
end;

Procedure TInterpreterTests.Compare_InputAndTransposed_LogsSumOfAbsoluteDifferences;
// Cells (i,j) and (j,i) differ by 9*|i-j|, which sums to 72 over all cells
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['compare','  matrices: 1,2']);
  Assert.IsTrue(LogContains('run.log','Sum of absolute differences: 72'));
end;

Procedure TInterpreterTests.Compare_TransposedSelection_LogsAndSelectsTransposedCells;
// Matrix 3 doubles transposed matrix 2, so they differ by the cells of matrix 2.
// Cells (1,2) and (1,3) of matrix 2 hold 21 and 31.
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['scale','  matrix: 2','  factor: 2','  id: 3'] +
          ['compare','  matrices: 2,3','  rows: 1','  columns: 2-3']);
  var Log := TFile.ReadAllText(FilePath('run.log'));
  Assert.IsTrue(Log.Contains('Rows: 1' + sLineBreak),Log);
  Assert.IsTrue(Log.Contains('Columns: 2,3' + sLineBreak),Log);
  Assert.IsTrue(Log.Contains('Sum of absolute differences: 52'),Log);
end;

Procedure TInterpreterTests.Init_TwoRuns_ExecutesBothRuns;
begin
  Execute(InitCommand + ReadCommand + WriteCommand(1,'first.csv') +
          InitCommand + ReadCommand +
          ['scale','  matrix: 1','  factor: 2','  id: 2'] +
          WriteCommand(2,'second.csv'));
  AssertOutputMatrix('first.csv');
  AssertOutputMatrix('second.csv',Function(Row,Column: Integer): Float64
                                  begin
                                    Result := 2*InputValue(Row,Column);
                                  end);
end;

Procedure TInterpreterTests.Init_TwoRunsSameLog_LogsBothRuns;
// The input matrix totals 198, its double 396
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand + ['stats','  matrices: 1'] +
          ['init','  size: 3','  log: run.log'] + ReadCommand +
          ['scale','  matrix: 1','  factor: 2','  id: 2'] +
          ['stats','  matrices: 2']);
  Assert.IsTrue(LogContains('run.log','Total: 198'),'First run');
  Assert.IsTrue(LogContains('run.log','Total: 396'),'Second run');
end;

Procedure TInterpreterTests.Init_ExistingLog_IsOverwritten;
begin
  TFile.WriteAllText(FilePath('run.log'),'Previous execution',TEncoding.ASCII);
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand + ['stats','  matrices: 1']);
  Assert.IsFalse(LogContains('run.log','Previous execution'));
end;

Procedure TInterpreterTests.Parameter_InFileName_IsReplaced;
begin
  Execute(InitCommand + ReadCommand + WriteCommand(1,'%name%.csv'),
          TKeyValuePairs.Create([TKeyValuePair.Create('name','output')]));
  AssertOutputMatrix('output.csv');
end;

Procedure TInterpreterTests.Execute_ValidScript_CountsNoErrors;
begin
  Execute(InitCommand + ReadCommand + WriteCommand(1,'output.csv'));
  Assert.AreEqual(0,ErrorCount);
end;

Procedure TInterpreterTests.Execute_InvalidCommand_CountsError;
// The error is raised while interpreting the script
begin
  Execute(InitCommand + ReadCommand + ['unknown']);
  Assert.AreEqual(1,ErrorCount);
end;

Procedure TInterpreterTests.Execute_MissingInputFile_CountsError;
// The error is raised while executing the run
begin
  Execute(InitCommand +
          ['read','  file: missing.csv','  format: txt','  delim: comma','  header: false','  id: 1','  ids: 1'] +
          WriteCommand(1,'output.csv'));
  Assert.AreEqual(1,ErrorCount);
end;

Procedure TInterpreterTests.Execute_ErrorInFirstRun_ExecutesNextRun;
begin
  Execute(InitCommand + ['unknown'] + ReadCommand + WriteCommand(1,'first.csv') +
          InitCommand + ReadCommand + WriteCommand(1,'second.csv'));
  Assert.AreEqual(1,ErrorCount);
  Assert.IsFalse(TFile.Exists(FilePath('first.csv')),'First run');
  AssertOutputMatrix('second.csv');
end;

Procedure TInterpreterTests.Execute_ErrorInMiddleRun_SkipsItsRemainingCommands;
begin
  Execute(InitCommand + ReadCommand + WriteCommand(1,'first.csv') +
          InitCommand + ['unknown'] + ReadCommand + WriteCommand(1,'second.csv') +
          InitCommand + ReadCommand + WriteCommand(1,'third.csv'));
  Assert.AreEqual(1,ErrorCount);
  AssertOutputMatrix('first.csv');
  Assert.IsFalse(TFile.Exists(FilePath('second.csv')),'Second run');
  AssertOutputMatrix('third.csv');
end;

Procedure TInterpreterTests.Write_UnknownFormat_LogsNoMatrixWriter;
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
          ['write','  matrices: 1','  file: output.csv','  format: txtt']);
  Assert.AreEqual(1,ErrorCount);
  Assert.IsTrue(LogContains('run.log','No matrix writer for format txtt'),TFile.ReadAllText(FilePath('run.log')));
end;

Procedure TInterpreterTests.Write_OmxWithoutDll_LogsDllNotFound;
// The test executable has no hdf5.dll next to it
begin
  if Hdf5Dll = nil then
  begin
    Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
            ['write','  matrices: 1','  file: output.omx','  format: omx']);
    Assert.AreEqual(1,ErrorCount);
    Assert.IsTrue(LogContains('run.log','Matrix format omx is not available: hdf5.dll not found'),
                  TFile.ReadAllText(FilePath('run.log')));
  end else
    Assert.Pass('hdf5.dll is loaded');
end;

Procedure TInterpreterTests.Read_OmxWithoutDll_LogsDllNotFound;
// The input file must exist; its content is not read
begin
  if Hdf5Dll = nil then
  begin
    TFile.WriteAllText(FilePath('input.omx'),'',TEncoding.ASCII);
    Execute(['init','  size: 3','  log: run.log'] +
            ['read','  file: input.omx','  format: omx','  ids: 1'] +
            WriteCommand(1,'output.csv'));
    Assert.AreEqual(1,ErrorCount);
    Assert.IsTrue(LogContains('run.log','Matrix format omx is not available: hdf5.dll not found'),
                  TFile.ReadAllText(FilePath('run.log')));
  end else
    Assert.Pass('hdf5.dll is loaded');
end;

Procedure TInterpreterTests.Command_OwnIdAsSource_LogsInvalidMatrixId(const Command: String);
// A matrix cannot be derived from itself, as it does not exist before the command
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand + [Command]);
  Assert.IsTrue(LogContains('run.log','Invalid matrix id 2'),TFile.ReadAllText(FilePath('run.log')));
end;

Procedure TInterpreterTests.Round_InvalidDigits_LogsInvalidDigits(const Digits: String);
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
          ['round','  matrix: 1','  digits: ' + Digits,'  id: 2']);
  Assert.AreEqual(1,ErrorCount);
  Assert.IsTrue(LogContains('run.log','Invalid digits value (' + Digits + ')'),TFile.ReadAllText(FilePath('run.log')));
end;

initialization
  TDUnitX.RegisterTestFixture(TInterpreterTests);
end.
