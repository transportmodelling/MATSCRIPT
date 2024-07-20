unit Script;

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Classes, Math, Log, ArrayHlp, PropSet, Ranges, matio, matio.formats, matio.io;

Type
  TFileStatus = (fsUnused,fsIndexed,fsLabeled);

  TMatrixIndexSelection = Class
  private
    Selection: TArray<Integer>;
  end;

  TMatrixLabelSelection = Class
  private
    Selection: TArray<String>;
  end;

  TInputMatrixFile = Class
  private
    Type
      TSelection = record
        case Status: TFileStatus of
          fsIndexed: (Indices: TMatrixIndexSelection);
          fsLabeled: (Labels: TMatrixLabelSelection);
      end;
    Var
      Line: Integer;
      FileProperties: TPropertySet;
      Selection: TSelection;
      Reader: TMatrixRowsReader;
    Procedure OpenFile(Size: Integer);
  public
    Function Used: Boolean;
    Destructor Destroy; override;
  end;

  TMatrixRow = Class(TVirtualMatrixRow)
  public
    Constructor Create(Size: Integer);
  end;

  TInputMatrixRow = Class(TMatrixRow)
  private
    MatrixFile: TInputMatrixFile;
    MatrixIndex: Integer;
  strict protected
    Function GetValues(Column: Integer): Float64; override;
  end;

  TConstantMatrixRow = Class(TMatrixRow)
  private
    Value: Float64;
  strict protected
    Function GetValues(Column: Integer): Float64; override;
  end;

  TScaledMatrixRow = Class(TMatrixRow)
  private
    ScaleFactor: Float64;
    Matrix: TVirtualMatrixRow;
  strict protected
    Function GetValues(Column: Integer): Float64; override;
  end;

  TMergedMatrixRow = Class(TMatrixRow)
  private
    Matrices: array of TVirtualMatrixRow;
  strict protected
    Function GetValues(Column: Integer): Float64; override;
  end;

  TDifferenceMatrixRow = Class(TMatrixRow)
  private
    Minuend,Subtrahend: TVirtualMatrixRow;
  strict protected
    Function GetValues(Column: Integer): Float64; override;
  end;

  TInfoLogger = Class
  strict protected
    Function FloatToStr(const Float: Float64): string;
  private
    Procedure Update(Row: Integer); virtual; abstract;
    Procedure LogInfo; virtual; abstract;
  end;

  TMatrixStatistics = Class(TInfoLogger)
  private
    Size: Integer;
    MinRow,MinColumn,MaxRow,MaxColumn: Integer;
    Min,Max,Diagonal,Total: Float64;
    Matrices,Rows,Columns: TRanges;
    MatrixRows: array of TVirtualMatrixRow;
    Constructor Create;
    Procedure Update(Row: Integer); override;
    Procedure LogInfo; override;
  end;

  TSumOfAbsoluteDifferences = Class(TInfoLogger)
  private
    Size: Integer;
    Matrices: TArray<Integer>;
    SumOfAbsoluteDifferences: Float64;
    MatrixRows: array[0..1] of TVirtualMatrixRow;
    Procedure Update(Row: Integer); override;
    Procedure LogInfo; override;
  end;

  TOutputMatrixFile = Class
  private
    Matrices: array of TVirtualMatrixRow;
    Writer: TMatrixWriter;
    Procedure Write;
  public
    Destructor Destroy; override;
  end;

  TScriptInterpreter = Class
  private
    FileName: String;
    LineCount,Size,MaxFileId,NFiles,MaxMatrixId,NMatrices: Integer;
    FileIndices: array {file id} of Integer;
    InputMatrixFiles: array {file index} of TInputMatrixFile;
    MatrixIndices: array {matrix id} of Integer;
    Tags: array {matrix index} of String;
    Matrices: array {matrix index} of TVirtualMatrixRow;
    InfoLoggers: array {logger} of TInfoLogger;
    OutputMatrixFiles: array of TOutputMatrixFile;
    Procedure RegisterMatrix(const MatrixId: Integer);
    Procedure CreateInputMatrix(const [ref] Arguments: TPropertySet; const FileIndex: Integer);
    Procedure InterpretInitCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretReadCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretMatrixCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretConstCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretScaleCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretMergeCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretSubtractCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretStatisticsCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretSumOfAbsoluteDifferencesCommand(const [ref] Arguments: TPropertySet);
    Procedure InterpretWriteCommand(const [ref] Arguments: TPropertySet);
    Function InterpretLine(const Command,Arguments: String): Boolean;
    Procedure InterpretLines;
  public
    Procedure Execute(const ScriptFileName: String);
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TInputMatrixFile.OpenFile(Size: Integer);
begin
  LogFile.InputFile('Line '+Line.ToString,FileProperties.ToPath(TMatrixFormat.FileProperty));
  case Selection.Status of
    fsIndexed: Reader := TMatrixRowsReader.Create(FileProperties,Selection.Indices.Selection,Size);
    fsLabeled: Reader := TMatrixRowsReader.Create(FileProperties,Selection.Labels.Selection,Size);
  end;
end;

Function TInputMatrixFile.Used: Boolean;
begin
  Result := (Selection.Status <> fsUnused);
end;

Destructor TInputMatrixFile.Destroy;
begin
  Reader.Free;
  case Selection.Status of
    fsIndexed: Selection.Indices.Free;
    fsLabeled: Selection.Labels.Free;
  end;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixRow.Create(Size: Integer);
begin
  inherited Create;
  Init(Size);
end;

////////////////////////////////////////////////////////////////////////////////

Function TInputMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := MatrixFile.Reader[MatrixIndex,Column];
end;

////////////////////////////////////////////////////////////////////////////////

Function TConstantMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := Value;
end;

////////////////////////////////////////////////////////////////////////////////

Function TScaledMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := ScaleFactor*Matrix.Values[Column];
end;

////////////////////////////////////////////////////////////////////////////////

Function TMergedMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := 0.0;
  for var Matrix := low(Matrices) to high(Matrices) do Result := Result + Matrices[Matrix].Values[Column];
end;

////////////////////////////////////////////////////////////////////////////////

Function TDifferenceMatrixRow.GetValues(Column: Integer): Float64;
begin
  Result := Minuend[Column]-Subtrahend[Column];
end;

////////////////////////////////////////////////////////////////////////////////

Function TInfoLogger.FloatToStr(const Float: Float64): string;
begin
  if Abs(Float) < 1 then Result := FormatFloat('0.#####',Float) else
  if Abs(Float) < 10 then Result := FormatFloat('0.####',Float) else
  if Abs(Float) < 100 then Result := FormatFloat('0.###',Float) else
  if Abs(Float) < 1000 then Result := FormatFloat('0.##',Float) else
  if Abs(Float) < 10000 then Result := FormatFloat('0.#',Float) else
  Result := FormatFloat('0',Float);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixStatistics.Create;
begin
  inherited Create;
  Min := Infinity;
  Max := NegInfinity;
end;

Procedure TMatrixStatistics.Update(Row: Integer);
begin
  if Rows.Contains(Row) then
  for var Column := 0 to Size-1 do
  if Columns.Contains(Column+1) then
  for var MatrixRow := low(MatrixRows) to high(MatrixRows) do
  begin
    var Value := MatrixRows[MatrixRow].Values[Column];
    if Value < Min then
    begin
      Min := Value;
      MinRow := Row;
      MinColumn := Column+1;
    end;
    if Value > Max then
    begin
      Max := Value;
      MaxRow := Row;
      MaxColumn := Column+1;
    end;
    if Row = Column+1 then Diagonal := Diagonal + Value;
    Total := Total +Value;
  end;
end;

Procedure TMatrixStatistics.LogInfo;
begin
  LogFile.Log;
  LogFile.Log('Matrices: ' + Matrices.AsString);
  LogFile.Log('Rows: ' + Rows.AsString);
  LogFile.Log('Columns: ' + Columns.AsString);
  LogFile.Log('Minimum: ' + FloatToStr(Min) + ' (row='+ MinRow.ToString + '; column=' +
                                                          MinColumn.ToString + ')');
  LogFile.Log('Maximum: ' + FloatToStr(Max) + ' (row='+ MaxRow.ToString + '; column=' +
                                                          MaxColumn.ToString + ')');
  LogFile.Log('Diagonal: ' + FloatToStr(Diagonal));
  LogFile.Log('Total: ' + FloatToStr(Total));
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TSumOfAbsoluteDifferences.Update(Row: Integer);
begin
  for var Column := 0 to Size-1 do
  SumOfAbsoluteDifferences := SumOfAbsoluteDifferences +
    Abs(MatrixRows[0].Values[Column]-MatrixRows[1].Values[Column]);
end;

Procedure TSumOfAbsoluteDifferences.LogInfo;
begin
  LogFile.Log;
  LogFile.Log('Matrices: ' + Matrices[0].ToString+','+Matrices[1].ToString);
  LogFile.Log('Sum of absolute differences: ' + FloatToStr(SumOfAbsoluteDifferences));
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TOutputMatrixFile.Write;
begin
  Writer.Write(Matrices);
end;

Destructor TOutputMatrixFile.Destroy;
begin
  Writer.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Procedure TScriptInterpreter.RegisterMatrix(const MatrixId: Integer);
begin
  if MatrixId > 0 then
  begin
    // Allocate matrix indices
    if MaxMatrixId < MatrixId then
    begin
      SetLength(MatrixIndices,MatrixId);
      for var Id := MaxMatrixId to MatrixId-1 do MatrixIndices[Id] := -1;
      MaxMatrixId := MatrixId;
    end;
    // Create matrix
    if MatrixIndices[MatrixId-1] < 0 then
    begin
      MatrixIndices[MatrixId-1] := NMatrices;
      Inc(NMatrices);
    end else
      raise Exception.Create('Matrix Id ' + MatrixId.ToString + ' already used');
  end else
    raise Exception.Create('Invalid matrix id' + MatrixId.ToString);
end;

Procedure TScriptInterpreter.CreateInputMatrix(const [ref] Arguments: TPropertySet; const FileIndex: Integer);
Var
  Tag: String;
begin
  // Get reference type
  var Indexed := Arguments.Contains('index');
  var Labeled := Arguments.Contains('label');
  if (not Indexed) and (not Labeled) then raise Exception.Create('Missing matrix reference');
  if Indexed and Labeled then raise Exception.Create('Ambiguous matrix reference');
  // Update file status
  case InputMatrixFiles[FileIndex].Selection.Status of
    fsUnused:
      begin
        if Indexed and (not Labeled) then
        begin
          // Create index selection
          InputMatrixFiles[FileIndex].Selection.Status := fsIndexed;
          InputMatrixFiles[FileIndex].Selection.Indices := TMatrixIndexSelection.Create;
        end else
        if (not Indexed) and Labeled then
        begin
          // Create label selection
          InputMatrixFiles[FileIndex].Selection.Status := fsLabeled;
          InputMatrixFiles[FileIndex].Selection.Labels := TMatrixLabelSelection.Create;
        end;
      end;
    fsIndexed:
        if Labeled then raise Exception.Create('Matrix index expected');
    fsLabeled:
        if Indexed then raise Exception.Create('Matrix label expected');
  end;
  // Create matrix
  var Matrix := TInputMatrixRow.Create(Size);
  Matrix.MatrixFile := InputMatrixFiles[FileIndex];
  if not Arguments.ContainsValue('tag',Tag) then
  if not Arguments.ContainsValue('label',Tag) then
  Tag := Arguments['id'];
  // Update selection
  case InputMatrixFiles[FileIndex].Selection.Status of
    fsIndexed:
      begin
        var Indx := Arguments.ToInt('index')-1;
        Matrix.MatrixIndex := InputMatrixFiles[FileIndex].Selection.Indices.Selection.Length;
        InputMatrixFiles[FileIndex].Selection.Indices.Selection.Append([Indx]);
      end;
    fsLabeled:
      begin
        var Lbl := Arguments['label'];
        Matrix.MatrixIndex := InputMatrixFiles[FileIndex].Selection.Labels.Selection.Length;
        InputMatrixFiles[FileIndex].Selection.Labels.Selection.Append([Lbl]);
      end;
  end;
  Tags := Tags + [Tag];
  Matrices := Matrices + [Matrix];
end;

Procedure TScriptInterpreter.InterpretInitCommand(const [ref] Arguments: TPropertySet);
begin
  Size := Arguments.ToInt('size');
  if Arguments.Contains('log') then
    LogFile := TLogFile.Create(Arguments.ToPath('log'),true)
  else
    LogFile := TLogFile.Create;
  LogFile.InputFile('Script',FileName);
end;

Procedure TScriptInterpreter.InterpretReadCommand(const [ref] Arguments: TPropertySet);
begin
  // Set file properties
  var FileId := Arguments.ToInt('id',0);
  SetLength(InputMatrixFiles,NFiles+1);
  InputMatrixFiles[NFiles] := TInputMatrixFile.Create;
  InputMatrixFiles[NFiles].Line := LineCount;
  InputMatrixFiles[NFiles].Selection.Status := fsUnused;
  InputMatrixFiles[NFiles].FileProperties := Arguments;
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
      var MatrixId := Arguments.ToInt('id');
      RegisterMatrix(MatrixId);
      CreateInputMatrix(Arguments,FileIndex);
    end else
      raise Exception.Create('Invalid file id');
  end else
    raise Exception.Create('Invalid file id');
end;

Procedure TScriptInterpreter.InterpretConstCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var MatrixId := Arguments.ToInt('id');
  RegisterMatrix(MatrixId);
  // Create matrix
  var Matrix := TConstantMatrixRow.Create(Size);
  Matrix.Value := Arguments.ToFloat('value');
  Tags := Tags + [Arguments.ToStr('tag',MatrixId.ToString)];
  Matrices := Matrices + [Matrix];
end;

Procedure TScriptInterpreter.InterpretScaleCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var MatrixId := Arguments.ToInt('id');
  RegisterMatrix(MatrixId);
  // Create matrix
  MatrixId := Arguments.ToInt('matrix');
  if (MatrixId > 0) and (MatrixId < Length(MatrixIndices)) then
  begin
    var MatrixIndex := MatrixIndices[MatrixId-1];
    if MatrixIndex >= 0 then
    begin
      var ScaledMatrix := TScaledMatrixRow.Create(Size);
      ScaledMatrix.ScaleFactor := Arguments.ToFloat('factor');
      ScaledMatrix.Matrix := Matrices[MatrixIndex];
      Tags := Tags + [Arguments.ToStr('tag',MatrixId.ToString)];
      Matrices := Matrices + [ScaledMatrix];
    end else
      raise Exception.Create('Invalid matrix id' + MatrixId.ToString);
  end else
    raise Exception.Create('Invalid matrix id' + MatrixId.ToString);
end;

Procedure TScriptInterpreter.InterpretMergeCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var MatrixId := Arguments.ToInt('id');
  RegisterMatrix(MatrixId);
  // Create matrix
  var MatrixIds := TRanges.Create(Arguments['matrices']).Values;
  var MergedMatrix := TMergedMatrixRow.Create(Size);
  for var Matrix := low(MatrixIds) to high(MatrixIds) do
  if (MatrixIds[Matrix] > 0) and (MatrixIds[Matrix] < Length(MatrixIndices)) then
  begin
    var MatrixIndex := MatrixIndices[MatrixIds[Matrix]-1];
    if MatrixIndex >= 0 then
      MergedMatrix.Matrices := MergedMatrix.Matrices + [Matrices[MatrixIndex]]
    else
      begin
        MergedMatrix.Free;
        raise Exception.Create('Invalid matrix id' + MatrixIds[Matrix].ToString);
      end;
  end else
  begin
    MergedMatrix.Free;
    raise Exception.Create('Invalid matrix id' + MatrixIds[Matrix].ToString);
  end;
  Tags := Tags + [Arguments.ToStr('tag',MatrixId.ToString)];
  Matrices := Matrices + [MergedMatrix];
end;

Procedure TScriptInterpreter.InterpretSubtractCommand(const [ref] Arguments: TPropertySet);
begin
  // Register matrix
  var MatrixId := Arguments.ToInt('id');
  RegisterMatrix(MatrixId);
  // Create matrix
  var Minuend := Arguments.ToInt('minuend');
  if (Minuend > 0) and (Minuend < Length(MatrixIndices)) then
  begin
    var MinuendIndex := MatrixIndices[Minuend-1];
    var Subtrahend := Arguments.ToInt('subtrahend');
    if (Subtrahend > 0) and (Subtrahend < Length(MatrixIndices)) then
    begin
      var SubtrahendIndex := MatrixIndices[Subtrahend-1];
      var DifferenceMatrix := TDifferenceMatrixRow.Create(Size);
      DifferenceMatrix.Minuend := Matrices[MinuendIndex];
      DifferenceMatrix.Subtrahend := Matrices[SubtrahendIndex];
      Tags := Tags + [Arguments.ToStr('tag',MatrixId.ToString)];
      Matrices := Matrices + [DifferenceMatrix];
    end else
      raise Exception.Create('Invalid subtrahend matrix id');
  end else
    raise Exception.Create('Invalid minuend matrix id');
end;

Procedure TScriptInterpreter.InterpretStatisticsCommand(const [ref] Arguments: TPropertySet);
Var
  RowSelection,ColumnSelection: String;
begin
  var Statistics := TMatrixStatistics.Create;
  Statistics.Size := Size;
  Statistics.Matrices := TRanges.Create(Arguments['matrices']);
  // Set matrix selection
  var MatrixIds := Statistics.Matrices.Values;
  for var Matrix := low(MatrixIds) to high(MatrixIds) do
  if (MatrixIds[Matrix] > 0) and (MatrixIds[Matrix] <= Length(MatrixIndices)) then
  begin
    var MatrixIndex := MatrixIndices[MatrixIds[Matrix]-1];
    if MatrixIndex >= 0 then
      Statistics.MatrixRows := Statistics.MatrixRows + [Matrices[MatrixIndex]]
    else
      begin
        Statistics.Free;
        raise Exception.Create('Invalid matrix id' + MatrixIds[Matrix].ToString);
      end;
  end else
  begin
    Statistics.Free;
    raise Exception.Create('Invalid matrix id' + MatrixIds[Matrix].ToString);
  end;
  // Set selected rows
  if Arguments.Contains('rows',RowSelection) then
    Statistics.Rows := TRanges.Create(RowSelection)
  else
    Statistics.Rows := TRanges.Create([TRange.Create(1,Size)]);
  // Set selected columns
  if Arguments.Contains('columns',ColumnSelection) then
    Statistics.Columns := TRanges.Create(ColumnSelection)
  else
    Statistics.Columns := TRanges.Create([TRange.Create(1,Size)]);
  InfoLoggers := InfoLoggers + [Statistics];
end;

Procedure TScriptInterpreter.InterpretSumOfAbsoluteDifferencesCommand(const [ref] Arguments: TPropertySet);
begin
  var SumOfAbsoluteDifferences := TSumOfAbsoluteDifferences.Create;
  SumOfAbsoluteDifferences.Size := Size;
  SumOfAbsoluteDifferences.Matrices := TRanges.Create(Arguments['matrices']).Values;
  if Length(SumOfAbsoluteDifferences.Matrices) = 2 then
  begin
    for var Matrix := 0 to 1 do
    begin
      var MatrixIndex := MatrixIndices[SumOfAbsoluteDifferences.Matrices[Matrix]-1];
      if MatrixIndex >= 0 then
        SumOfAbsoluteDifferences.MatrixRows[Matrix] := Matrices[MatrixIndex]
      else
        begin
          SumOfAbsoluteDifferences.Free;
          raise Exception.Create('Invalid matrix id' + Matrices[Matrix].ToString);
        end;
    end;
    InfoLoggers := InfoLoggers + [SumOfAbsoluteDifferences];
  end else
  begin
    SumOfAbsoluteDifferences.Free;
    raise Exception.Create('Invalid number of matrices');
  end;
end;

Procedure TScriptInterpreter.InterpretWriteCommand(const [ref] Arguments: TPropertySet);
Var
  MatrixTags: array of String;
begin
  var FileLabel := Arguments.ToStr('label','');
  var FileMatrices := TRanges.Create(Arguments['matrices']).Values;
  if FileMatrices.Length > 0 then
  begin
    var OutputMatrixFile := TOutputMatrixFile.Create;
    SetLength(MatrixTags,FileMatrices.Length);
    SetLength(OutputMatrixFile.Matrices,FileMatrices.Length);
    for var Matrix := 0 to FileMatrices.Length-1 do
    if (FileMatrices[Matrix] > 0) and (FileMatrices[Matrix] <= Length(MatrixIndices)) then
    begin
      var MatrixIndex := MatrixIndices[FileMatrices[Matrix]-1];
      if MatrixIndex >= 0 then
      begin
        MatrixTags[Matrix] := Tags[MatrixIndex];
        OutputMatrixFile.Matrices[Matrix] := Matrices[MatrixIndex];
      end else
      begin
        OutputMatrixFile.Free;
        raise Exception.Create('Unknown matrix ' + FileMatrices[Matrix].ToString);
      end;
    end else
    begin
      OutputMatrixFile.Free;
      raise Exception.Create('Unknown matrix ' + FileMatrices[Matrix].ToString);
    end;
    OutputMatrixFile.Writer := MatrixFormats.CreateWriter(Arguments,FileLabel,MatrixTags,Size);
    OutputMatrixFiles := OutputMatrixFiles + [OutputMatrixFile];
    LogFile.OutputFile('Line: '+LineCount.ToString,Arguments.ToPath(TMatrixFormat.FileProperty));
  end;
end;

Function TScriptInterpreter.InterpretLine(const Command,Arguments: String): Boolean;
begin
  if SameText(Command,'init') then
  begin
    Result := true;
    InterpretInitCommand(Arguments);
  end else
  if SameText(Command,'read') then
  begin
    Result := true;
    InterpretReadCommand(Arguments);
  end else
  if SameText(Command,'matrix') then
  begin
    Result := true;
    InterpretMatrixCommand(Arguments);
  end else
  if SameText(Command,'const') then
  begin
    Result := true;
    InterpretConstCommand(Arguments);
  end else
  if SameText(Command,'scale') then
  begin
    Result := true;
    InterpretScaleCommand(Arguments);
  end else
  if SameText(Command,'merge') then
  begin
    Result := true;
    InterpretMergeCommand(Arguments);
  end else
  if SameText(Command,'subtract') then
  begin
    Result := true;
    InterpretSubtractCommand(Arguments);
  end else
  if SameText(Command,'sad') then
  begin
    Result := true;
    InterpretSumOfAbsoluteDifferencesCommand(Arguments);
  end else
  if SameText(Command,'stats') then
  begin
    Result := true;
    InterpretStatisticsCommand(Arguments);
  end else
  if SameText(Command,'write') then
  begin
    Result := true;
    InterpretWriteCommand(Arguments);
  end else
    Result := false;
end;

Procedure TScriptInterpreter.InterpretLines;
begin
  var ScriptReader := TStreamReader.Create(FileName);
  try
    LineCount := 0;
    while not ScriptReader.EndOfStream do
    begin
      var Line := Trim(ScriptReader.ReadLine);
      Inc(LineCount);
      if (Line <> '') and (Line[1] <> '*') then
      begin
        var SpacePos := Pos(' ',Line);
        var Command := Copy(Line,1,SpacePos-1);
        var Arguments := Copy(Line,SpacePos+1,MaxInt);
        try
          if not InterpretLine(Command,Arguments) then raise Exception.Create('Invalid command')
        except
          on E: Exception do raise Exception.Create(E.Message + ' at line ' + LineCount.ToString);
        end;
      end;
    end;
  finally
    ScriptReader.Free;
  end;
end;

Procedure TScriptInterpreter.Execute(const ScriptFileName: String);
begin
  try
    FileName := ScriptFileName;
    InterpretLines;
    for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do
    if InputMatrixFiles[MatrixFl].Used then InputMatrixFiles[MatrixFl].OpenFile(Size);
    for var Row := 0 to Size-1 do
    begin
      for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do
      if InputMatrixFiles[MatrixFl].Used then InputMatrixFiles[MatrixFl].Reader.Read;
      for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do InfoLoggers[InfoLogger].Update(Row+1);
      for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do OutputMatrixFiles[MatrixFl].Write;
    end;
    for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do InfoLoggers[InfoLogger].LogInfo;
  finally
    for var MatrixFl := low(InputMatrixFiles) to high(InputMatrixFiles) do InputMatrixFiles[MatrixFl].Free;
    for var Matrix := low(Matrices) to high(Matrices) do Matrices[Matrix].Free;
    for var InfoLogger := low(InfoLoggers) to high(InfoLoggers) do InfoLoggers[InfoLogger].Free;
    for var MatrixFl := low(OutputMatrixFiles) to high(OutputMatrixFiles) do OutputMatrixFiles[MatrixFl].Free;
    LogFile.Free;
  end;
end;

end.
