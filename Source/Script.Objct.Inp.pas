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
  SysUtils, PropSet, ArrayHlp, Log, matio, matio.io, matio.formats, Script.Objct, Script.Objct.Row;

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

  TInputMatrixFile = Class(TScriptObject)
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
  public
    Constructor Create(const LineNr: Integer; const [ref] InputFileProperties: TPropertySet);
    Procedure OpenFile;
    Procedure Read;
    Procedure CloseFile;
    Function CreateMatrix(const [ref] MatrixProperties: TPropertySet): TScriptMatrixRow;
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

Constructor TInputMatrixFile.Create(const LineNr: Integer; const [ref] InputFileProperties: TPropertySet);
begin
  inherited Create;
  Line := LineNr;
  FileProperties := InputFileProperties;
end;

Procedure TInputMatrixFile.OpenFile;
begin
  LogFile.InputFile('Line '+Line.ToString,FileProperties.ToPath(TMatrixFormat.FileProperty));
  case Selection.Status of
    fsIndexed: Reader := TMatrixRowsReader.Create(FileProperties,Selection.Indices.Selection,Size);
    fsLabeled: Reader := TMatrixRowsReader.Create(FileProperties,Selection.Labels.Selection,Size);
  end;
end;

Procedure TInputMatrixFile.Read;
begin
  Reader.Read;
end;

Procedure TInputMatrixFile.CloseFile;
begin
  FreeAndNil(Reader);
end;

Function TInputMatrixFile.CreateMatrix(const [ref] MatrixProperties: TPropertySet): TScriptMatrixRow;
Var
  Tag: String;
begin
  // Get reference type
  var Indexed := MatrixProperties.Contains('index');
  var Labeled := MatrixProperties.Contains('label');
  if (not Indexed) and (not Labeled) then raise Exception.Create('Missing matrix reference');
  if Indexed and Labeled then raise Exception.Create('Ambiguous matrix reference');
  // Update file status
  case Selection.Status of
    fsUnused:
      begin
        if Indexed and (not Labeled) then
        begin
          // Create index selection
          Selection.Status := fsIndexed;
          Selection.Indices := TMatrixIndexSelection.Create;
        end else
        if (not Indexed) and Labeled then
        begin
          // Create label selection
          Selection.Status := fsLabeled;
          Selection.Labels := TMatrixLabelSelection.Create;
        end;
      end;
    fsIndexed:
        if Labeled then raise Exception.Create('Matrix index expected');
    fsLabeled:
        if Indexed then raise Exception.Create('Matrix label expected');
  end;
  // Create matrix
  var Id := MatrixProperties.ToInt('id');
  var Matrix := TInputMatrixRow.Create(Id);
  Matrix.Tag := MatrixProperties.ToStr('tag','');
  Matrix.MatrixFile := Self;
  // Update selection
  case Selection.Status of
    fsIndexed:
      begin
        var Indx := MatrixProperties.ToInt('index')-1;
        Matrix.MatrixIndex := Selection.Indices.Selection.Length;
        Selection.Indices.Selection.Append([Indx]);
      end;
    fsLabeled:
      begin
        var Lbl := MatrixProperties['label'];
        Matrix.MatrixIndex := Selection.Labels.Selection.Length;
        Selection.Labels.Selection.Append([Lbl]);
      end;
  end;
  Result := Matrix;
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
