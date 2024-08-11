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
  SysUtils, PropSet, ArrayBld, matio, matio.formats, Script.Objct, Script.Objct.Row;

Type
  TOutputMatrixFile = Class(TScriptObject)
  private
    FileProperties: TPropertySet;
    FileLabel: String;
    MatrixRows: TArray<TScriptMatrixRow>;
    Delegates: TArray<TVirtualMatrixRow>;
    Writer: TMatrixWriter;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(const OutputFileProperties: TPropertySet;
                       const OutputFileLabel: String;
                       const OutputMatrices: array of TScriptMatrixRow);
    Procedure OpenFile;
    Procedure Write;
    Procedure CloseFile;
    Destructor Destroy; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TOutputMatrixFile.Create(const OutputFileProperties: TPropertySet;
                                     const OutputFileLabel: String;
                                     const OutputMatrices: array of TScriptMatrixRow);
begin
  inherited Create;
  FileProperties := OutputFileProperties;
  FileLabel := OutputFileLabel;
  FNDependencies := Length(OutputMatrices);
  SetLength(Delegates,Length(OutputMatrices));
  MatrixRows := TArrayBuilder<TScriptMatrixRow>.Create(OutputMatrices);
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
  Writer := MatrixFormats.CreateWriter(FileProperties,FileLabel,MatrixLabels,Size);
end;

Procedure TOutputMatrixFile.Write;
begin
  for var Mtrx := low(MatrixRows) to high(MatrixRows) do Delegates[Mtrx] := MatrixRows[Mtrx].Delegate;
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
