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
  SysUtils, IOUtils, DUnitX.TestFramework, KeyVal, Parse, MatrixScript;

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

    // Info commands
    [Test] Procedure Totals_InputMatrix_WritesRowAndColumnTotals;
    [Test] Procedure Stats_InputMatrix_LogsTotalAndDiagonal;
    [Test] Procedure Compare_InputAndTransposed_LogsSumOfAbsoluteDifferences;

    // Script structure
    [Test] Procedure Init_TwoRuns_ExecutesBothRuns;
    [Test] Procedure Parameter_InFileName_IsReplaced;
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

Procedure TInterpreterTests.Compare_InputAndTransposed_LogsSumOfAbsoluteDifferences;
// Cells (i,j) and (j,i) differ by 9*|i-j|, which sums to 72 over all cells
begin
  Execute(['init','  size: 3','  log: run.log'] + ReadCommand +
          ['transpose','  matrix: 1','  id: 2'] +
          ['compare','  matrices: 1,2']);
  Assert.IsTrue(LogContains('run.log','Sum of absolute differences: 72'));
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

Procedure TInterpreterTests.Parameter_InFileName_IsReplaced;
begin
  Execute(InitCommand + ReadCommand + WriteCommand(1,'%name%.csv'),
          TKeyValuePairs.Create([TKeyValuePair.Create('name','output')]));
  AssertOutputMatrix('output.csv');
end;

initialization
  TDUnitX.RegisterTestFixture(TInterpreterTests);
end.
