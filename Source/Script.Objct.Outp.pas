unit Script.Objct.Outp;

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
  SysUtils, KeyVal, ArrBld, matio, matio.writer, matio.formats, Script.Objct, Script.Objct.Row;

Type
  TOutputMatrixFile = Class(TScriptObject)
  private
    FileProperties: TKeyValuePairs;
    MatrixRows: TArray<TScriptMatrixRow>;
    Delegates: TArray<TVirtualMatrixRow>;
    Writer: TMatrixWriter;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(const OutputFileProperties: TKeyValuePairs;
                       const OutputMatrices: array of TScriptMatrixRow);
    Procedure OpenFile;
    Procedure Write;
    Procedure CloseFile;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TOutputMatrixFile.Create(const OutputFileProperties: TKeyValuePairs;
                                     const OutputMatrices: array of TScriptMatrixRow);
begin
  inherited Create;
  FileProperties := OutputFileProperties;
  FNDependencies := Length(OutputMatrices);
  MatrixRows := TArrayBuilder<TScriptMatrixRow>.Create(OutputMatrices);
  SetLength(Delegates,Length(OutputMatrices));
  for var Matrix := low(MatrixRows) to high(MatrixRows) do Delegates[Matrix] := MatrixRows[Matrix].Delegate;
  SetStage;
end;

Function TOutputMatrixFile.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := MatrixRows[Dependency];
end;

Procedure TOutputMatrixFile.OpenFile;
Var
  MatrixLabels: array of String;
begin
  SetLength(MatrixLabels,NDependencies);
  for var Matrix := 0 to NDependencies-1 do
  begin
    MatrixLabels[Matrix] := MatrixRows[Matrix].Tag;
    if MatrixLabels[Matrix] = '' then MatrixLabels[Matrix] := 'matrix_'+ MatrixRows[Matrix].Id.ToString;
  end;
  // MatrixFormats creates no writer when the format is unknown or unavailable.
  // Output files carry no file label.
  var MatrixWriter := MatrixFormats.CreateWriter(FileProperties,'',MatrixLabels,Size);
  if MatrixWriter <> nil then
    Writer := MatrixWriter
  else
    raise Exception.Create(MatrixFormats.WriterUnavailability(FileProperties));
end;

Procedure TOutputMatrixFile.Write;
begin
  Writer.Write(Delegates);
end;

Procedure TOutputMatrixFile.CloseFile;
begin
  FreeAndNil(Writer);
end;

Destructor TOutputMatrixFile.Destroy;
begin
  Writer.Free;
  inherited Destroy;
end;

end.
