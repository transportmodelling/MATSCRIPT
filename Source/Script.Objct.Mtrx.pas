unit Script.Objct.Mtrx;

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
  mat, matio, ArrayBld, Script.Objct, Script.Objct.Row;

Type
  TMemMatrix = Class(TStagedObject)
  // Calculates the sum of matrices. The result is hold in memory because
  // at least 1 of the Matrices is transposed, so a full cycle over all rows
  // is required to obtain the result.
  private
    Rows: TArray<TScriptMatrixRow>;
    Matrix: TFloat64Matrices;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
    Procedure Update(Row: Integer); override;
  public
    Constructor Create(const MatrixRows: array of TScriptMatrixRow);
    Destructor Destroy; override;
  end;

  TMemMatrixReader = Class(TScriptMatrixRow)
  private
    MemMatrix: TMemMatrix;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(const Id: Integer; const Matrix: TMemMatrix);
    Function GetValues(const Column: Integer): Float64; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMemMatrix.Create(const MatrixRows: array of TScriptMatrixRow);
begin
  inherited Create;
  FNDependencies := Length(MatrixRows);
  Rows := TArrayBuilder<TScriptMatrixRow>.Create(MatrixRows);
  Matrix := TFloat64Matrices.Create(1,Size);
end;

Function TMemMatrix.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Rows[Dependency];
end;

Procedure TMemMatrix.Update(Row: Integer);
begin
  for var MatrixRow in Rows do
  if MatrixRow.Transposed then
    for var Column := 0 to Size-1 do
      Matrix.Values[0,Column,Row-1] := Matrix.Values[0,Column,Row-1] + MatrixRow.GetValues(Column)
  else
    for var Column := 0 to Size-1 do
      Matrix.Values[0,Row-1,Column] := Matrix.Values[0,Row-1,Column] + MatrixRow.GetValues(Column)
end;

Destructor TMemMatrix.Destroy;
begin
  Matrix.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMemMatrixReader.Create(const Id: Integer; const Matrix: TMemMatrix);
begin
  inherited Create(Id);
  FNDependencies := 1;
  MemMatrix := Matrix;
  SetStage;
end;

Function TMemMatrixReader.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := MemMatrix;
end;

Function TMemMatrixReader.GetValues(const Column: Integer): Float64;
begin
  Result := MemMatrix.Matrix[0,Row,Column];
end;

end.