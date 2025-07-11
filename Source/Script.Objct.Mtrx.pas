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
  TMatrixOperation = (moSum,moProduct);

  TMemMatrix = Class(TStagedObject)
  // Calculates the sum of matrices. The result is hold in memory because
  // at least 1 of the Matrices is transposed, so a full cycle over all rows
  // is required to obtain the result.
  private
    Rows: TArray<TScriptMatrixRow>;
    Operation: TMatrixOperation;
    Matrix: TFloat64Matrices;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
    Procedure Update(Row: Integer); override;
  public
    Constructor Create(const MatrixRows: array of TScriptMatrixRow; MatrixOperation: TMatrixOperation);
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

Constructor TMemMatrix.Create(const MatrixRows: array of TScriptMatrixRow; MatrixOperation: TMatrixOperation);
begin
  inherited Create;
  FNDependencies := Length(MatrixRows);
  Rows := TArrayBuilder<TScriptMatrixRow>.Create(MatrixRows);
  Operation := MatrixOperation;
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
    case Operation of
      moSum: Matrix.Values[0,Column,Row] := Matrix.Values[0,Column,Row] + MatrixRow.GetValues(Column);
      moProduct: Matrix.Values[0,Column,Row] := Matrix.Values[0,Column,Row]*MatrixRow.GetValues(Column)
    end
  else
    for var Column := 0 to Size-1 do
      Matrix.Values[0,Row,Column] := Matrix.Values[0,Row,Column] + MatrixRow.GetValues(Column)
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
