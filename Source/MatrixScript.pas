unit MatrixScript;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/MATSCRIPT
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Math, Log, Parse, ArrHlp, KeyVal, Ranges, Script, matio, matio.formats, matio.io,
  matio.writer, matio.writer.text, Script.Objct, Script.Objct.Row, Script.Objct.Mtrx, Script.Objct.Inp, Script.Objct.Outp,
  Script.Objct.Info, Script.Objct.Info.Stats, Script.Objct.Info.Totals;

Type
  TMatrixScriptInterpreter = Class(TScriptInterpreter)
  private
    Var
      FErrorCount: Integer;
      MaxFileId,NFiles,MaxMatrixId,NMatrices: Integer;
      FileIndices: array {file id} of Integer;
      InputMatrixFiles: array {file index} of TInputMatrixFile;
      MatrixIndices: array {matrix id} of Integer;
      Matrices,MemMatrices: array {matrix index} of TScriptMatrixRow;
      InfoLoggers: array {logger} of TInfoLogger;
      StagedObjects: array {object} of TStagedObject;
      OutputMatrixFiles: array of TOutputMatrixFile;
      LogFileNames: array of String; // Log files of the runs so far
    Procedure RegisterMatrix(const Id: Integer);
    Function  GetMatrix(const Id: Integer): TScriptMatrixRow;
    Function  CreateMemMatrixReader(const Id: Integer;
                                    const MatrixRows: array of TScriptMatrixRow;
                                    const Operation: TMatrixOperation): TMemMatrixReader;
    Function  GetMemMatrix(const Matrix: TScriptMatrixRow): TScriptMatrixRow;
    Function  GetMatrices(const Ids: array of Integer; out NTransposedMatrices,NSymmetricMatrices: Integer): TArray<TScriptMatrixRow>;
    Procedure CreateInputMatrix(const [ref] Arguments: TKeyValuePairs; const FileIndex: Integer);
    Function  LogFileUsed(const FileName: String): Boolean;
    Function  CreateLogFile(const FileName: String): TLogFile;
    Procedure InterpretReadCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretMatrixCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretConstCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretScaleCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretRoundCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretCombineCommand(const [ref] Arguments: TKeyValuePairs; const Operation: TMatrixOperation);
    Procedure InterpretTransposeCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretStatisticsCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretTotalsCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretCompareCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure InterpretWriteCommand(const [ref] Arguments: TKeyValuePairs);
    Procedure ActivateStage(const Stage: Integer);
    Procedure OpenStageFiles(const Stage: Integer);
    Procedure ReadRow(const Stage,Row: Integer);
    Procedure UpdateRow(const Stage,Row: Integer);
    Procedure WriteRow(const Stage: Integer);
    Procedure CloseStageFiles(const Stage: Integer);
    Procedure ExecuteStage(const Stage: Integer);
  strict protected
    Procedure InitializeRun; override;
    Procedure InterpretInitCommand(const [ref] Arguments: TKeyValuePairs); override;
    Function InterpretCommand(const Command: String; const [ref] Arguments: TKeyValuePairs): Boolean; override;
    Procedure RunCompleted; override;
    Procedure FinalizeRun; override;
    Procedure HandleException(const E: Exception); override;
  public
    // The number of runs that raised an exception
    Property ErrorCount: Integer read FErrorCount;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Const
  // The matrix row classes that combine matrices by an operation, cell by cell
  CombinedMatrixRowClasses: array[TMatrixOperation] of TCombinedMatrixRowClass = (TMergedMatrixRow,TProductMatrixRow);

////////////////////////////////////////////////////////////////////////////////

Procedure TMatrixScriptInterpreter.RegisterMatrix(const Id: Integer);
// Commands get their source matrices before registering the matrix they create,
// so a command cannot take the matrix it creates as a source.
begin
  if Id > 0 then
  begin
    // Allocate matrix indices
    if MaxMatrixId < Id then
    begin
      SetLength(MatrixIndices,Id);
      for var MatrixId := MaxMatrixId to Id-1 do MatrixIndices[MatrixId] := -1;
      MaxMatrixId := Id;
    end;
    // Create matrix
    if MatrixIndices[Id-1] < 0 then
    begin
      MatrixIndices[Id-1] := NMatrices;
      Inc(NMatrices);
    end else
      raise Exception.Create('Matrix Id ' + Id.ToString + ' already used');
  end else
    raise Exception.Create('Invalid matrix id ' + Id.ToString);
end;

Function TMatrixScriptInterpreter.GetMatrix(const Id: Integer): TScriptMatrixRow;
begin
  if (Id > 0) and (Id <= Length(MatrixIndices)) then
  begin
    var Index := MatrixIndices[Id-1];
    if Index >= 0 then
      Result := Matrices[Index]
    else
      raise Exception.Create('Invalid matrix id ' + Id.ToString);
  end else
    raise Exception.Create('Invalid matrix id ' + Id.ToString);
end;

Function TMatrixScriptInterpreter.CreateMemMatrixReader(const Id: Integer;
                                                        const MatrixRows: array of TScriptMatrixRow;
                                                        const Operation: TMatrixOperation): TMemMatrixReader;
// Holds the combination of the matrices in memory, for a reader in the next stage
begin
  var MemMatrix := TMemMatrix.Create(MatrixRows,Operation);
  Result := TMemMatrixReader.Create(Id,MemMatrix);
  StagedObjects := StagedObjects + [MemMatrix];
end;

Function TMatrixScriptInterpreter.GetMemMatrix(const Matrix: TScriptMatrixRow): TScriptMatrixRow;
begin
  if Matrix.Transposed then
  begin
    var Index := MatrixIndices[Matrix.Id-1];
    SetLength(MemMatrices,Length(Matrices));
    if MemMatrices[Index] = nil then
    begin
      // Store matrix in memory and create reader.
      // The memory matrix reader gets the same Id, but it is not registered.
      MemMatrices[Index] := CreateMemMatrixReader(Matrix.Id,[Matrix],moSum);
      MemMatrices[Index].Tag := Matrix.Tag;
      Matrices := Matrices + [MemMatrices[Index]];
      Inc(NMatrices);
    end;
    Result := MemMatrices[Index];
  end else
    Result := Matrix;
end;

Function TMatrixScriptInterpreter.GetMatrices(const Ids: array of Integer; out NTransposedMatrices,NSymmetricMatrices: Integer): TArray<TScriptMatrixRow>;
begin
  NTransposedMatrices := 0;
  NSymmetricMatrices := 0;
  SetLength(Result,Length(Ids));
  for var Matrix := low(Ids) to high(Ids) do
  begin
    Result[Matrix] := GetMatrix(Ids[Matrix]);
    if Result[Matrix].Symmetric then Inc(NSymmetricMatrices);
    if Result[Matrix].Transposed then Inc(NTransposedMatrices);
  end;
end;

Procedure TMatrixScriptInterpreter.CreateInputMatrix(const [ref] Arguments: TKeyValuePairs; const FileIndex: Integer);
begin
  // Create matrix
  var Matrix := InputMatrixFiles[FileIndex].CreateMatrix(Arguments);
  Matrices := Matrices + [Matrix];
end;

Function TMatrixScriptInterpreter.LogFileUsed(const FileName: String): Boolean;
begin
  for var LogFileName in LogFileNames do
  if SameFileName(LogFileName,FileName) then Exit(true);
  Result := false;
end;

Function TMatrixScriptInterpreter.CreateLogFile(const FileName: String): TLogFile;
// A log file is overwritten by the first run that uses it. Later runs append
// to it, so the log file holds all runs, each starting after a separator line.
begin
  if LogFileUsed(FileName) then
    Result := TLogFile.Create(FileName,'-',80,true)
  else
    begin
      Result := TLogFile.Create(FileName,true);
      LogFileNames := LogFileNames + [FileName];
    end;
end;

Procedure TMatrixScriptInterpreter.InitializeRun;
begin
  MaxFileId := 0;
  NFiles := 0;
  MaxMatrixId := 0;
  NMatrices := 0;
  TScriptObject.MaxStage := 0;
  Finalize(FileIndices);
  Finalize(InputMatrixFiles);
  Finalize(MatrixIndices);
  Finalize(Matrices);
  Finalize(MemMatrices);
  Finalize(InfoLoggers);
  Finalize(StagedObjects);
  Finalize(OutputMatrixFiles);
end;

Procedure TMatrixScriptInterpreter.InterpretInitCommand(const [ref] Arguments: TKeyValuePairs);
begin
  TScriptObject.Size := Arguments.Int('size');
  TMatrixWriter.RoundToZeroThreshold := Arguments.ToFloat('round',0);
  TTextMatrixWriter.RowLabel := Arguments.ToStr('row','Row');
  TTextMatrixWriter.ColumnLabel := Arguments.ToStr('column','Column');
  if TScriptObject.Size > 0 then
  begin
    if Arguments.Contains('log') then
      LogFile := CreateLogFile(Arguments.Path('log'))
    else
      LogFile := TLogFile.Create;
    LogFile.InputFile('Script',ScriptFileName);
  end else
    raise Exception.Create('Invalid Size-value');
end;

Procedure TMatrixScriptInterpreter.InterpretReadCommand(const [ref] Arguments: TKeyValuePairs);
begin
  // Set file properties
  var FileId := Arguments.ToInt('id',0);
  SetLength(InputMatrixFiles,NFiles+1);
  InputMatrixFiles[NFiles] := TInputMatrixFile.Create(LineNr,Arguments);
  // Set file index
  if FileId > 0 then
  begin
    if MaxFileId < FileId then
    begin
      SetLength(FileIndices,FileId);
      for var Id := MaxFileId to FileId-1 do FileIndices[Id] := -1;
      MaxFileId := FileId;
    end;
    if FileIndices[FileId-1] < 0 then
      FileIndices[FileId-1] := NFiles
    else
      raise Exception.Create('File Id ' + FileId.ToString + ' already used');
  end;
  // Create matrices
  var MatrixIds := TRanges.Create(Arguments.ToStr('ids','')).Values;
  for var Index := low(MatrixIds) to high(MatrixIds) do
  if MatrixIds[Index] > 0 then
  begin
    RegisterMatrix(MatrixIds[Index]);
    var MatrixProperties: TKeyValuePairs := nil;
    MatrixProperties.Append('index',(Index+1).ToString);
    MatrixProperties.Append('id',MatrixIds[Index].ToString);
    CreateInputMatrix(MatrixProperties,NFiles);
  end;
  // Increase files count
  Inc(NFiles);
end;

Procedure TMatrixScriptInterpreter.InterpretMatrixCommand(const [ref] Arguments: TKeyValuePairs);
begin
  var FileId := Arguments.Int('file');
  if (FileId > 0) and (FileId <= MaxFileId) then
  begin
    var FileIndex := FileIndices[FileId-1];
    if FileIndex >= 0 then
    begin
      var Id := Arguments.Int('id');
      RegisterMatrix(Id);
      CreateInputMatrix(Arguments,FileIndex);
    end else
      raise Exception.Create('Invalid file id');
  end else
    raise Exception.Create('Invalid file id');
end;

Procedure TMatrixScriptInterpreter.InterpretConstCommand(const [ref] Arguments: TKeyValuePairs);
Var
  Matrix: TConstantMatrixRow;
begin
  // Register matrix
  var Id := Arguments.Int('id');
  RegisterMatrix(Id);
  // Create matrix
  var Values := TStringParser.Create(Comma,Arguments.ToStr('value',''));
  if Values.Count = 1 then Matrix := TConstantMatrixRow.Create(Id,Values[0]) else
  if Values.Count = 2 then Matrix := TConstantMatrixRow.Create(Id,Values[0],Values[1]) else
  raise Exception.Create('Invalid const value');
  Matrix.Tag := Arguments.ToStr('tag','');
  Matrices := Matrices + [Matrix];
end;

Procedure TMatrixScriptInterpreter.InterpretScaleCommand(const [ref] Arguments: TKeyValuePairs);
begin
  // Get source matrix
  var Matrix := GetMatrix(Arguments.Int('matrix'));
  // Register matrix
  var Id := Arguments.Int('id');
  RegisterMatrix(Id);
  // Create matrix
  var ScaleFactor := Arguments.Float('factor');
  var ScaledMatrix := TScaledMatrixRow.Create(Id,ScaleFactor,Matrix);
  ScaledMatrix.Tag := Arguments.ToStr('tag','');
  Matrices := Matrices + [ScaledMatrix];
end;

Procedure TMatrixScriptInterpreter.InterpretRoundCommand(const [ref] Arguments: TKeyValuePairs);
begin
  // Get source matrix and number of decimal places
  var Matrix := GetMatrix(Arguments.Int('matrix'));
  var NDigits := Arguments.ToInt('digits',0);
  if (NDigits >= 0) and (NDigits <= TRoundedMatrixRow.MaxDigits) then
  begin
    // Register matrix
    var Id := Arguments.Int('id');
    RegisterMatrix(Id);
    // Create matrix
    var RoundedMatrix := TRoundedMatrixRow.Create(Id,NDigits,Matrix);
    RoundedMatrix.Tag := Arguments.ToStr('tag','');
    Matrices := Matrices + [RoundedMatrix];
  end else
    raise Exception.Create('Invalid digits value (' + NDigits.ToString + ')');
end;

Procedure TMatrixScriptInterpreter.InterpretCombineCommand(const [ref] Arguments: TKeyValuePairs; const Operation: TMatrixOperation);
// Combines matrices cell by cell: the merge-command sums them, the multiply-command
// multiplies them. A combination of transposed and other matrices is held in memory.
Var
  NTransposedMatrices,NSymmetricMatrices: Integer;
  Matrix: TScriptMatrixRow;
begin
  // Set matrix selection
  var Ids := TRanges.Create(Arguments.ToStr('matrices','')).Values;
  var CombinedMatrices := GetMatrices(Ids,NTransposedMatrices,NSymmetricMatrices);
  // Register matrix
  var Id := Arguments.Int('id');
  RegisterMatrix(Id);
  // Create combined matrix
  if (NTransposedMatrices = 0) or (NSymmetricMatrices + NTransposedMatrices = Ids.Length) then
    Matrix := CombinedMatrixRowClasses[Operation].Create(Id,NSymmetricMatrices = Ids.Length,
                                                         NTransposedMatrices > 0,CombinedMatrices)
  else
    Matrix := CreateMemMatrixReader(Id,CombinedMatrices,Operation);
  Matrix.Tag := Arguments.ToStr('tag','');
  Matrices := Matrices + [Matrix];
end;

Procedure TMatrixScriptInterpreter.InterpretTransposeCommand(const [ref] Arguments: TKeyValuePairs);
begin
  // Get source matrix
  var MatrixId := Arguments.Int('matrix');
  var Matrix := GetMatrix(MatrixId);
  // Register matrix
  var Id := Arguments.Int('id');
  RegisterMatrix(Id);
  // Create transposed matrix
  var TransposedMatrix := TTransposedMatrixRow.Create(Id,Matrix);
  TransposedMatrix.Tag := Arguments.ToStr('tag','');
  Matrices := Matrices + [TransposedMatrix];
end;

Procedure TMatrixScriptInterpreter.InterpretStatisticsCommand(const [ref] Arguments: TKeyValuePairs);
Var
  Rows,Columns: TRanges;
  Selection: String;
  NTransposedMatrices,NSymmetricMatrices: Integer;
begin
  // Set Rows selection
  if Arguments.Contains('rows',Selection) then
    Rows := TRanges.Create(Selection)
  else
    Rows := TRanges.Create([TRange.Create(1,TScriptObject.Size)]);
  // Set Columns selection
  if Arguments.Contains('columns',Selection) then
    Columns := TRanges.Create(Selection)
  else
    Columns := TRanges.Create([TRange.Create(1,TScriptObject.Size)]);
  // Set matrix selection
  var Ids := TRanges.Create(Arguments.ToStr('matrices','')).Values;
  var StatisticsMatrices := GetMatrices(Ids,NTransposedMatrices,NSymmetricMatrices);
  // Create statistics object
  var StatisticsLogger := TMatrixStatisticsLogger.Create(Rows,Columns,StatisticsMatrices);
  InfoLoggers := InfoLoggers + [StatisticsLogger];
end;

Procedure TMatrixScriptInterpreter.InterpretTotalsCommand(const [ref] Arguments: TKeyValuePairs);
Var
  NTransposedMatrices,NSymmetricMatrices: Integer;
  TotalsLogger: TMatrixTotalsLogger;
begin
  // Set matrix selection
  var Ids := TRanges.Create(Arguments.ToStr('matrices','')).Values;
  var TotalsMatrices := GetMatrices(Ids,NTransposedMatrices,NSymmetricMatrices);
  // Create statistics object
  var FileName := Arguments.Path(TMatrixFormat.FileProperty);
  var Delimiter := Arguments.ToStr('delim',Tab.ToString);
  TotalsLogger := TMatrixTotalsLogger.Create(FileName,TDelimiter.Create(Delimiter),TotalsMatrices);
  LogFile.OutputFile('Line: '+LineNr.ToString,FileName);
  InfoLoggers := InfoLoggers + [TotalsLogger];
end;

Procedure TMatrixScriptInterpreter.InterpretCompareCommand(const [ref] Arguments: TKeyValuePairs);
Var
  Id0,Id1: Integer;
  Rows,Columns: TRanges;
  Selection: String;
  SumOfAbsoluteDifferences: TSumOfAbsoluteDifferences;
begin
  TStringParser.Create(Comma,Arguments.ToStr('matrices','')).AssignToVar([Id0,Id1]);
  // Set Rows selection
  if Arguments.Contains('rows',Selection) then
    Rows := TRanges.Create(Selection)
  else
    Rows := TRanges.Create([TRange.Create(1,TScriptObject.Size)]);
  // Set Columns selection
  if Arguments.Contains('columns',Selection) then
    Columns := TRanges.Create(Selection)
  else
    Columns := TRanges.Create([TRange.Create(1,TScriptObject.Size)]);
  // Set matrix selection
  var Matrix0 := GetMatrix(Id0);
  var Matrix1 := GetMatrix(Id1);
  // When only one of the matrices is transposed, compare its copy in memory
  if Matrix0.Transposed <> Matrix1.Transposed then
  begin
    Matrix0 := GetMemMatrix(Matrix0);
    Matrix1 := GetMemMatrix(Matrix1);
  end;
  // Create info object
  SumOfAbsoluteDifferences := TSumOfAbsoluteDifferences.Create(Rows,Columns,Matrix0,Matrix1);
  InfoLoggers := InfoLoggers + [SumOfAbsoluteDifferences];
end;

Procedure TMatrixScriptInterpreter.InterpretWriteCommand(const [ref] Arguments: TKeyValuePairs);
Var
  OutputMatrices: array of TScriptMatrixRow;
begin
  // Get Output matrices
  var Ids := TRanges.Create(Arguments.ToStr('matrices','')).Values;
  SetLength(OutputMatrices,Ids.Length);
  for var Matrix := low(Ids) to high(Ids) do
  begin
    OutputMatrices[Matrix] := GetMatrix(Ids[Matrix]);
    if OutputMatrices[Matrix].Transposed then
    begin
      var MemMatrix := GetMemMatrix(OutputMatrices[Matrix]);
      OutputMatrices[Matrix] := MemMatrix;
    end;
  end;
  // Create output file
  var FileLabel := '';
  var OutputMatrixFile := TOutputMatrixFile.Create(Arguments,FileLabel,OutputMatrices);
  OutputMatrixFiles := OutputMatrixFiles + [OutputMatrixFile];
  LogFile.OutputFile('Line: '+LineNr.ToString,Arguments.Path(TMatrixFormat.FileProperty));
end;

Procedure TMatrixScriptInterpreter.ActivateStage(const Stage: Integer);
// Activating the objects of a stage activates the objects they depend on,
// among them the input files that are read in this stage
begin
  for var InfoLogger in InfoLoggers do
  if InfoLogger.Stage = Stage then InfoLogger.Active[Stage] := true;
  for var StagedObject in StagedObjects do
  if StagedObject.Stage = Stage then StagedObject.Active[Stage] := true;
  for var OutputFile in OutputMatrixFiles do
  if OutputFile.Stage = Stage then OutputFile.Active[Stage] := true;
end;

Procedure TMatrixScriptInterpreter.OpenStageFiles(const Stage: Integer);
// The tags of input matrices come from their opened input files, and are
// written to the output files
begin
  for var InputFile in InputMatrixFiles do
  if InputFile.Active[Stage] then InputFile.OpenFile;
  for var Matrix in Matrices do Matrix.UpdateTag;
  for var OutputFile in OutputMatrixFiles do
  if OutputFile.Active[Stage] then OutputFile.OpenFile;
end;

Procedure TMatrixScriptInterpreter.ReadRow(const Stage,Row: Integer);
begin
  for var InputFile in InputMatrixFiles do
  if InputFile.Active[Stage] then InputFile.Read;
  for var Matrix in Matrices do Matrix.Row := Row;
end;

Procedure TMatrixScriptInterpreter.UpdateRow(const Stage,Row: Integer);
begin
  for var InfoLogger in InfoLoggers do
  if InfoLogger.Active[Stage] then InfoLogger.Update(Row);
  for var StagedObject in StagedObjects do
  if StagedObject.Active[Stage] then StagedObject.Update(Row);
end;

Procedure TMatrixScriptInterpreter.WriteRow(const Stage: Integer);
begin
  for var OutputFile in OutputMatrixFiles do
  if OutputFile.Stage = Stage then OutputFile.Write;
end;

Procedure TMatrixScriptInterpreter.CloseStageFiles(const Stage: Integer);
begin
  for var InputFile in InputMatrixFiles do
  if InputFile.Active[Stage] then InputFile.CloseFile;
  for var OutputFile in OutputMatrixFiles do
  if OutputFile.Active[Stage] then OutputFile.CloseFile;
end;

Procedure TMatrixScriptInterpreter.ExecuteStage(const Stage: Integer);
// Iterates once over all rows, for the objects of the stage and those they depend on
begin
  ActivateStage(Stage);
  OpenStageFiles(Stage);
  for var Row := 0 to TScriptObject.Size-1 do
  begin
    ReadRow(Stage,Row);
    UpdateRow(Stage,Row);
    WriteRow(Stage);
  end;
  CloseStageFiles(Stage);
end;

Function TMatrixScriptInterpreter.InterpretCommand(const Command: String; const [ref] Arguments: TKeyValuePairs): Boolean;
begin
  Result := true;
  if SameText(Command,'read') then InterpretReadCommand(Arguments) else
  if SameText(Command,'matrix') then InterpretMatrixCommand(Arguments) else
  if SameText(Command,'const') then InterpretConstCommand(Arguments) else
  if SameText(Command,'scale') then InterpretScaleCommand(Arguments) else
  if SameText(Command,'round') then InterpretRoundCommand(Arguments) else
  if SameText(Command,'merge') then InterpretCombineCommand(Arguments,moSum) else
  if SameText(Command,'multiply') then InterpretCombineCommand(Arguments,moProduct) else
  if SameText(Command,'transpose') then InterpretTransposeCommand(Arguments) else
  if SameText(Command,'compare') then InterpretCompareCommand(Arguments) else
  if SameText(Command,'stats') then InterpretStatisticsCommand(Arguments) else
  if SameText(Command,'totals') then InterpretTotalsCommand(Arguments) else
  if SameText(Command,'write') then InterpretWriteCommand(Arguments) else
  Result := false;
end;

Procedure TMatrixScriptInterpreter.RunCompleted;
begin
  for var Stage := 0 to TScriptObject.MaxStage do ExecuteStage(Stage);
  for var InfoLogger in InfoLoggers do InfoLogger.LogInfo;
end;

Procedure TMatrixScriptInterpreter.FinalizeRun;
begin
  // Destroy objects
  for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do InputMatrixFiles[MatrixFl].Free;
  for var Matrix := low(Matrices) to high(Matrices) do Matrices[Matrix].Free;
  for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do InfoLoggers[InfoLogger].Free;
  for var StagedObject := low(StagedObjects) to high(StagedObjects) do StagedObjects[StagedObject].Free;
  for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do OutputMatrixFiles[MatrixFl].Free;
  FreeAndNil(LogFile);
end;

Procedure TMatrixScriptInterpreter.HandleException(const E: Exception);
begin
  Inc(FErrorCount);
  // The log file does not exist yet when the init-command has not completed
  if LogFile <> nil then
  begin
    LogFile.Log;
    LogFile.Log(E);
  end else
    writeln('ERROR: ',E.Message);
end;

end.
