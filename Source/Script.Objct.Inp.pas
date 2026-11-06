unit Script.Objct.Inp;

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
  SysUtils, KeyVal, Log, matio, matio.io, matio.formats, Script.Objct, Script.Objct.Row;

Type
  TFileStatus = (fsUnused,fsIndexed,fsLabeled);

  TInputMatrixFile = Class(TScriptObject)
  // All matrices of a file are selected by their index in the file, or all of
  // them by their label
  private
    Line: Integer;
    LoggedFileInfo: Boolean;
    FileProperties: TKeyValuePairs;
    Status: TFileStatus;
    Indices: TArray<Integer>; // Zero based indices of the selected matrices, when selected by index
    Labels: TArray<String>; // Labels of the selected matrices, when selected by label
    Reader: TMatrixRowsReader;
    Function ReferenceStatus(const [ref] MatrixProperties: TKeyValuePairs): TFileStatus;
    Procedure SetStatus(const MatrixStatus: TFileStatus);
    Function SelectMatrix(const [ref] MatrixProperties: TKeyValuePairs): Integer;
  public
    Constructor Create(const LineNr: Integer; const [ref] InputFileProperties: TKeyValuePairs);
    Procedure OpenFile;
    Procedure Read;
    Procedure CloseFile;
    Function CreateMatrix(const [ref] MatrixProperties: TKeyValuePairs): TScriptMatrixRow;
    Destructor Destroy; override;
  end;

  TInputMatrixRow = Class(TScriptMatrixRow)
  private
    MatrixFile: TInputMatrixFile;
    MatrixIndex: Integer;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
    Function GetValues(const Column: Integer): Float64; override;
  public
    Constructor Create(Id: Integer);
    Procedure UpdateTag; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TInputMatrixFile.Create(const LineNr: Integer; const [ref] InputFileProperties: TKeyValuePairs);
begin
  inherited Create;
  Line := LineNr;
  FileProperties := InputFileProperties;
end;

Function TInputMatrixFile.ReferenceStatus(const [ref] MatrixProperties: TKeyValuePairs): TFileStatus;
// A matrix is referenced by its index or by its label
begin
  var Indexed := MatrixProperties.Contains('index');
  var Labeled := MatrixProperties.Contains('label');
  if Indexed <> Labeled then
    if Indexed then Result := fsIndexed else Result := fsLabeled
  else if Indexed then
    raise Exception.Create('Ambiguous matrix reference')
  else
    raise Exception.Create('Missing matrix reference');
end;

Procedure TInputMatrixFile.SetStatus(const MatrixStatus: TFileStatus);
// The first matrix sets how the matrices of the file are referenced
begin
  if (Status = fsUnused) or (Status = MatrixStatus) then
    Status := MatrixStatus
  else if Status = fsIndexed then
    raise Exception.Create('Matrix index expected')
  else
    raise Exception.Create('Matrix label expected');
end;

Function TInputMatrixFile.SelectMatrix(const [ref] MatrixProperties: TKeyValuePairs): Integer;
// Adds a matrix to the selection; the result is its index within the selection
begin
  if Status = fsIndexed then
  begin
    Result := Length(Indices);
    Indices := Indices + [MatrixProperties.Int('index')-1];
  end else
  begin
    Result := Length(Labels);
    Labels := Labels + [MatrixProperties.Str('label')];
  end;
end;

Procedure TInputMatrixFile.OpenFile;
begin
  if TMatrixReaderFormat.FileExists(FileProperties) then
  begin
    // Log file info
    if not LoggedFileInfo then
    begin
      LoggedFileInfo := true;
      LogFile.InputFile('Line '+Line.ToString,FileProperties.Path(TMatrixFormat.FileProperty));
    end;
    // Create reader
    case Status of
      fsIndexed: Reader := TMatrixRowsReader.Create(FileProperties,Indices,Size);
      fsLabeled: Reader := TMatrixRowsReader.Create(FileProperties,Labels,Size);
    end;
  end else
    raise Exception.Create('File does not exist (' + TMatrixFormat.FileName(FileProperties,false) + ')');
end;

Procedure TInputMatrixFile.Read;
begin
  Reader.Read;
end;

Procedure TInputMatrixFile.CloseFile;
begin
  FreeAndNil(Reader);
end;

Function TInputMatrixFile.CreateMatrix(const [ref] MatrixProperties: TKeyValuePairs): TScriptMatrixRow;
begin
  SetStatus(ReferenceStatus(MatrixProperties));
  var Matrix := TInputMatrixRow.Create(MatrixProperties.Int('id'));
  Matrix.Tag := MatrixProperties.ToStr('tag','');
  Matrix.MatrixFile := Self;
  Matrix.MatrixIndex := SelectMatrix(MatrixProperties);
  Result := Matrix;
end;

Destructor TInputMatrixFile.Destroy;
begin
  Reader.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TInputMatrixRow.Create(Id: Integer);
begin
  inherited Create(Id);
  FNDependencies := 1;
end;

Procedure TInputMatrixRow.UpdateTag;
begin
  if Tag = '' then
  if MatrixFile.Reader <> nil then
  Tag := MatrixFile.Reader.MatrixLabels[MatrixIndex];
end;

Function TInputMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := MatrixFile;
end;

Function TInputMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := MatrixFile.Reader[MatrixIndex,Column];
end;

end.
