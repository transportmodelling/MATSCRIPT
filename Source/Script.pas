unit Script;

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
  SysUtils, Classes, Math, Log, Parse, ArrayHlp, PropSet, Ranges, matio, matio.formats, matio.io,
  matio.text, Script.Objct, Script.Objct.Row, Script.Objct.Mtrx, Script.Objct.Inp, Script.Objct.Outp,
  Script.Objct.Info;

Type
  TScriptInterpreter = Class
  private
    Type
      TLineHandling = (Handled,Postponed,Unhandled);
    Var
      ScriptReader: TStreamReader;
      FileName,Line: String;
      Initialized: Boolean;
      LineCount,MaxFileId,NFiles,MaxMatrixId,NMatrices: Integer;
      FileIndices: array {file id} of Integer;
      InputMatrixFiles: array {file index} of TInputMatrixFile;
      MatrixIndices: array {matrix id} of Integer;
      Matrices,MemMatrices: array {matrix index} of TScriptMatrixRow;
      InfoLoggers: array {logger} of TInfoLogger;
      StagedObjects: array {object} of TStagedObject;
      OutputMatrixFiles: array of TOutputMatrixFile;
    Procedure RegisterMatrix(const Id: Integer);
    Function  GetMatrix(const Id: Integer): TScriptMatrixRow;
    Function  GetMemMatrix(const Matrix: TScriptMatrixRow): TScriptMatrixRow;
    Function  GetMatrices(const Ids: array of Integer; out NTransposedMatrices,NSymmetricMatrices: Integer): TArray<TScriptMatrixRow>;
    Procedure CreateInputMatrix(const [ref] Arguments: TPropertySet; const FileIndex: Integer);
    Procedure InterpretInitCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretReadCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretMatrixCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretConstCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretScaleCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretRoundCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretMergeCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretTransposeCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretStatisticsCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretCompareCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretWriteCommand(const [ref] Arguments: TPropertySet);
    Function InterpretLine(const Command,Arguments: String): TLineHandling;
    Function InterpretLines(UnhandledLine: Boolean): Boolean;
  public
    Procedure Execute(const ScriptFileName: String);
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TScriptInterpreter.RegisterMatrix(const Id: Integer);
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

Function TScriptInterpreter.GetMatrix(const Id: Integer): TScriptMatrixRow;
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

Function TScriptInterpreter.GetMemMatrix(const Matrix: TScriptMatrixRow): TScriptMatrixRow;
begin
  if Matrix.Transposed then
  begin
    var Index := MatrixIndices[Matrix.Id-1];
    SetLength(MemMatrices,Length(Matrices));
    if MemMatrices[Index] = nil then
    begin
      // Store matrix in memomory and create reader.
      // The memory matrix reader gets the same Id, but it is not registered.
      var MemMatrix := TMemMatrix.Create([Matrix]);
      MemMatrices[Index] := TMemMatrixReader.Create(Matrix.Id,MemMatrix);
      MemMatrices[Index].Tag := Matrix.Tag;
      StagedObjects := StagedObjects + [MemMatrix];
      Matrices := Matrices + [MemMatrices[Index]];
    end;
    Result := MemMatrices[Index];
  end else
    Result := Matrix;
end;

Function TScriptInterpreter.GetMatrices(const Ids: array of Integer; out NTransposedMatrices,NSymmetricMatrices: Integer): TArray<TScriptMatrixRow>;
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

Procedure TScriptInterpreter.CreateInputMatrix(const [ref] Arguments: TPropertySet; const FileIndex: Integer);
begin
  // Create matrix
  var Matrix := InputMatrixFiles[FileIndex].CreateMatrix(Arguments);
  Matrices := Matrices + [Matrix];
end;

Procedure TScriptInterpreter.InterpretInitCommand(const [ref] Arguments: TPropertySet);
begin
  Initialized := true;
  TScriptObject.Size := Arguments.ToInt('size');
  TMatrixWriter.RoundToZeroThreshold := Arguments.ToFloat('round',0);
  TTextMatrixWriter.RowLabel := Arguments.ToStr('row','Row');
  TTextMatrixWriter.ColumnLabel := Arguments.ToStr('column','Column');
  if TScriptObject.Size > 0 then
  begin
    if Arguments.Contains('log') then
      LogFile := TLogFile.Create(Arguments.ToPath('log'),true)
    else
      LogFile := TLogFile.Create;
    LogFile.InputFile('Script',FileName);
  end else
    raise Exception.Create('Invalid Size-value');
end;

Procedure TScriptInterpreter.InterpretReadCommand(const [ref] Arguments: TPropertySet);
begin
  // Set file properties
  var FileId := Arguments.ToInt('id',0);
  SetLength(InputMatrixFiles,NFiles+1);
  InputMatrixFiles[NFiles] := TInputMatrixFile.Create(LineCount,Arguments);
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
  var MatrixIds := TRanges.Create(Arguments['ids']).Values;
  for var Index := low(MatrixIds) to high(MatrixIds) do
  if MatrixIds[Index] > 0 then
  begin
    RegisterMatrix(MatrixIds[Index]);
    var MatrixProperties := TPropertySet.Create(false);
    MatrixProperties.Append('index',(Index+1).ToString);
    MatrixProperties.Append('id',MatrixIds[Index].ToString);
    CreateInputMatrix(MatrixProperties,NFiles);
  end;
  // Increase files count
  Inc(NFiles);
end;

Procedure TScriptInterpreter.InterpretMatrixCommand(const [ref] Arguments: TPropertySet);
begin
  var FileId := Arguments.ToInt('file');
  if (FileId > 0) and (FileId <= MaxFileId) then
  begin
    var FileIndex := FileIndices[FileId-1];
    if FileIndex >= 0 then
    begin
      var Id := Arguments.ToInt('id');
      RegisterMatrix(Id);
      CreateInputMatrix(Arguments,FileIndex);
    end else
      raise Exception.Create('Invalid file id');
  end else
    raise Exception.Create('Invalid file id');
end;

Procedure TScriptInterpreter.InterpretConstCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var Id := Arguments.ToInt('id');
  RegisterMatrix(Id);
  // Create matrix
  var Value := Arguments.ToFloat('value');
  var Matrix := TConstantMatrixRow.Create(Id,Value);
  Matrix.Tag := Arguments['tag'];
  Matrices := Matrices + [Matrix];
end;

Procedure TScriptInterpreter.InterpretScaleCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var Id := Arguments.ToInt('id');
  RegisterMatrix(Id);
  // Create matrix
  var Matrix := GetMatrix(Arguments.ToInt('matrix'));
  var ScaleFactor := Arguments.ToFloat('factor');
  var ScaledMatrix := TScaledMatrixRow.Create(Id,ScaleFactor,Matrix);
  ScaledMatrix.Tag := Arguments['tag'];
  Matrices := Matrices + [ScaledMatrix];
end;

Procedure TScriptInterpreter.InterpretRoundCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var Id := Arguments.ToInt('id');
  RegisterMatrix(Id);
  // Create matrix
  var Matrix := GetMatrix(Arguments.ToInt('matrix'));
  var NDigits := Arguments.ToInt('digits',0);
  var RoundedMatrix := TRoundedMatrixRow.Create(Id,NDigits,Matrix);
  RoundedMatrix.Tag := Arguments['tag'];
  Matrices := Matrices + [RoundedMatrix];
end;

Procedure TScriptInterpreter.InterpretMergeCommand(const [ref] Arguments: TPropertySet);
Var
  NTransposedMatrices,NSymmetricMatrices: Integer;
begin
  // Register matrix
  var Id := Arguments.ToInt('id');
  RegisterMatrix(Id);
  // Set matrix selection
  var Ids := TRanges.Create(Arguments['matrices']).Values;
  var NMatrices := Ids.Length;
  var MergeMatrices := GetMatrices(Ids,NTransposedMatrices,NSymmetricMatrices);
  // Create merged matrix
  if NMatrices = NSymmetricMatrices then
  begin
    var MergedMatrix := TMergedMatrixRow.Create(Id,true,false,MergeMatrices);
    MergedMatrix.Tag := Arguments['tag'];
    Matrices := Matrices + [MergedMatrix];
  end else
  if NTransposedMatrices = 0 then
  begin
    var MergedMatrix := TMergedMatrixRow.Create(Id,false,false,MergeMatrices);
    MergedMatrix.Tag := Arguments['tag'];
    Matrices := Matrices + [MergedMatrix];
  end else
  if NMatrices = NSymmetricMatrices + NTransposedMatrices then
  begin
    var MergedMatrix := TMergedMatrixRow.Create(Id,false,true,MergeMatrices);
    MergedMatrix.Tag := Arguments['tag'];
    Matrices := Matrices + [MergedMatrix];
  end else
  begin
    var MemMatrix := TMemMatrix.Create(MergeMatrices);
    var MemMatrixReader := TMemMatrixReader.Create(Id,MemMatrix);
    MemMatrixReader.Tag := Arguments['tag'];
    StagedObjects := StagedObjects + [MemMatrix];
    Matrices := Matrices + [MemMatrixReader];
  end;
end;

Procedure TScriptInterpreter.InterpretTransposeCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var Id := Arguments.ToInt('id');
  RegisterMatrix(Id);
  // Create transposed matrix
  var MatrixId := Arguments.ToInt('matrix');
  var Matrix := GetMatrix(MatrixId);
  var TransposedMatrix := TTransposedMatrixRow.Create(Id,Matrix);
  TransposedMatrix.Tag := Arguments['tag'];
  Matrices := Matrices + [TransposedMatrix];
end;

Procedure TScriptInterpreter.InterpretStatisticsCommand(const [ref] Arguments: TPropertySet);
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
  var Ids := TRanges.Create(Arguments['matrices']).Values;
  var NMatrices := Length(Ids);
  var StatisticsMatrices := GetMatrices(Ids,NTransposedMatrices,NSymmetricMatrices);
  // Create info object
  if NTransposedMatrices = 0 then
  begin
    var Statistics := TMatrixStatistics.Create(Rows,Columns,StatisticsMatrices,false);
    InfoLoggers := InfoLoggers + [Statistics];
  end else
  begin
    // Create separate statistic for transposed and non-transposed matrices
    var TransposedStatistics := TMatrixStatistics.Create(Columns,Rows,StatisticsMatrices,true);
    var Statistics := TMatrixStatistics.Create(Rows,Columns,StatisticsMatrices,TransposedStatistics);
    InfoLoggers := InfoLoggers + [TransposedStatistics,Statistics];
  end;
end;

Procedure TScriptInterpreter.InterpretCompareCommand(const [ref] Arguments: TPropertySet);
Var
  Id0,Id1: Integer;
  Rows,Columns: TRanges;
  Selection: String;
  SumOfAbsoluteDifferences: TSumOfAbsoluteDifferences;
begin
  Arguments.Parse('matrices').AssignToVar([Id0,Id1]);
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
  // Create info object
  if Matrix0.Transposed then
    if Matrix1.Transposed then
      SumOfAbsoluteDifferences := TSumOfAbsoluteDifferences.Create(Columns,Rows,Matrix0,Matrix1)
    else
      begin
        var MemMatrix := GetMemMatrix(Matrix0);
        SumOfAbsoluteDifferences := TSumOfAbsoluteDifferences.Create(Rows,Columns,MemMatrix,Matrix1);
        Inc(NMatrices);
      end
  else
    if Matrix1.Transposed then
      begin
        var MemMatrix := GetMemMatrix(Matrix1);
        SumOfAbsoluteDifferences := TSumOfAbsoluteDifferences.Create(Rows,Columns,Matrix0,MemMatrix);
        Inc(NMatrices);
      end
    else
      SumOfAbsoluteDifferences := TSumOfAbsoluteDifferences.Create(Rows,Columns,Matrix0,Matrix1);
  InfoLoggers := InfoLoggers + [SumOfAbsoluteDifferences];
end;

Procedure TScriptInterpreter.InterpretWriteCommand(const [ref] Arguments: TPropertySet);
Var
  OutputMatrices: array of TScriptMatrixRow;
begin
  // Get Output matrices
  var Ids := TRanges.Create(Arguments['matrices']).Values;
  SetLength(OutputMatrices,Ids.Length);
  for var Matrix := low(Ids) to high(Ids) do
  begin
    OutputMatrices[Matrix] := GetMatrix(Ids[Matrix]);
    if OutputMatrices[Matrix].Transposed then
    begin
      var MemMatrix := GetMemMatrix(OutputMatrices[Matrix]);
      OutputMatrices[Matrix] := MemMatrix;
      Inc(NMatrices);
    end;
  end;
  // Create output file
  var FileLabel := '';
  var OutputMatrixFile := TOutputMatrixFile.Create(Arguments,FileLabel,OutputMatrices);
  OutputMatrixFiles := OutputMatrixFiles + [OutputMatrixFile];
  LogFile.OutputFile('Line: '+LineCount.ToString,Arguments.ToPath(TMatrixFormat.FileProperty));
end;

Function TScriptInterpreter.InterpretLine(const Command,Arguments: String): TLineHandling;
begin
  Result := Handled;
  if SameText(Command,'init') then
    if Initialized then Result := Postponed else InterpretInitCommand(Arguments)
  else
    if Initialized then
      if SameText(Command,'read') then InterpretReadCommand(Arguments) else
      if SameText(Command,'matrix') then InterpretMatrixCommand(Arguments) else
      if SameText(Command,'const') then InterpretConstCommand(Arguments) else
      if SameText(Command,'scale') then InterpretScaleCommand(Arguments) else
      if SameText(Command,'round') then InterpretRoundCommand(Arguments) else
      if SameText(Command,'merge') then InterpretMergeCommand(Arguments) else
      if SameText(Command,'transpose') then InterpretTransposeCommand(Arguments) else
      if SameText(Command,'compare') then InterpretCompareCommand(Arguments) else
      if SameText(Command,'stats') then InterpretStatisticsCommand(Arguments) else
      if SameText(Command,'write') then InterpretWriteCommand(Arguments) else
      Result := Unhandled
    else
      raise Exception.Create('Initialization required');
end;

Function TScriptInterpreter.InterpretLines(UnhandledLine: Boolean): Boolean;
// Interpret lines until the end of the script file, or the script is re-initialized.
// The result indicates whether all lines have been handled.
// The UnhandledLine-argument indicates whether an unhandled line is left from a previous call.
begin
  Initialized := false;
  while UnhandledLine or (not ScriptReader.EndOfStream) do
  begin
    if UnhandledLine then UnhandledLine := false else
    begin
      Inc(LineCount);
      Line := Trim(ScriptReader.ReadLine);
    end;
    if (Line <> '') and (Line[1] <> '*') then
    begin
      var SpacePos := Pos(' ',Line);
      var Command := Copy(Line,1,SpacePos-1);
      var Arguments := Copy(Line,SpacePos+1,MaxInt);
      try
        case InterpretLine(Command,Arguments) of
          Postponed: Exit(false);  // Script is re-initialized
          Unhandled: raise Exception.Create('Invalid command')
        end;
      except
        on E: Exception do raise Exception.Create(E.Message + ' at line ' + LineCount.ToString);
      end;
    end;
  end;
  Result := true;
end;

Procedure TScriptInterpreter.Execute(const ScriptFileName: String);
begin
  ScriptReader := TStreamReader.Create(ScriptFileName);
  try
    var AllLinesHandled := false;
    var UnhandledLine := false;
    FileName := ScriptFileName;
    repeat
      try
        // Initialize
        MaxFileId := 0;
        NFiles := 0;
        MaxMatrixId := 0;
        NMatrices := 0;
        Finalize(FileIndices);
        Finalize(InputMatrixFiles);
        Finalize(MatrixIndices);
        Finalize(Matrices);
        Finalize(MemMatrices);
        Finalize(InfoLoggers);
        Finalize(StagedObjects);
        Finalize(OutputMatrixFiles);
        // Interpret script
        AllLinesHandled := InterpretLines(UnhandledLine);
        UnhandledLine := not AllLinesHandled;
        // Execute script
        for var Stage := 0 to TScriptObject.MaxStage do
        begin
          // Activate staged objects.
          // This will activate required input files for this stage.
          for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do
          if InfoLoggers[InfoLogger].Stage = Stage then
          InfoLoggers[InfoLogger].Active[Stage] := true;
          for var StagedObject := low(StagedObjects) to high(StagedObjects) do
          if StagedObjects[StagedObject].Stage = Stage then
          StagedObjects[StagedObject].Active[Stage] := true;
          for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do
          if OutputMatrixFiles[MatrixFl].Stage = Stage then OutputMatrixFiles[MatrixFl].Active[Stage] := true;
          // Open input files
          for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do
          if InputMatrixFiles[MatrixFl].Active[Stage] then InputMatrixFiles[MatrixFl].OpenFile;
          // Update Tags
          for var Matrix := low(Matrices) to high(Matrices) do Matrices[Matrix].UpdateTag;
          // Open output files for this stage.
          for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do
          if OutputMatrixFiles[MatrixFl].Active[Stage] then OutputMatrixFiles[MatrixFl].OpenFile;
          // Iterate rows
          for var Row := 0 to TScriptObject.Size-1 do
          begin
            // Read input matrices
            for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do
            if InputMatrixFiles[MatrixFl].Active[Stage] then InputMatrixFiles[MatrixFl].Read;
            // Set matrix rows
            for var Matrix := low(Matrices) to high(Matrices) do Matrices[Matrix].Row := Row;
            // Update info loggers
            for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do
            if InfoLoggers[InfoLogger].Active[Stage] then
            InfoLoggers[InfoLogger].Update(Row+1);
            // Update (other) staged objects
            for var StagedObject := low(StagedObjects) to high(StagedObjects) do
            if StagedObjects[StagedObject].Active[Stage] then
            StagedObjects[StagedObject].Update(Row+1);
            // Write output files
            for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do
            if OutputMatrixFiles[MatrixFl].Stage = Stage then
            OutputMatrixFiles[MatrixFl].Write;
          end;
          // Close input files
          for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do
          if InputMatrixFiles[MatrixFl].Active[Stage] then InputMatrixFiles[MatrixFl].CloseFile;
          // Close output files
          for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do
          if OutputMatrixFiles[MatrixFl].Active[Stage] then OutputMatrixFiles[MatrixFl].CloseFile;
        end;
        // Log info
        for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do InfoLoggers[InfoLogger].LogInfo;
      finally
        // Destroy objects
        for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do InputMatrixFiles[MatrixFl].Free;
        for var Matrix := low(Matrices) to high(Matrices) do Matrices[Matrix].Free;
        for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do InfoLoggers[InfoLogger].Free;
        for var StagedObject := low(StagedObjects) to high(StagedObjects) do StagedObjects[StagedObject].Free;
        for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do OutputMatrixFiles[MatrixFl].Free;
        LogFile.Free;
      end;
    until not UnhandledLine;
  finally
    ScriptReader.Free;
  end;
end;

end.
