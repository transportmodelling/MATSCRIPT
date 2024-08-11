unit Script.Objct.Row;

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
  SysUtils, ArrayBld, matio, Script.Objct;

Type
  TScriptMatrixRow = Class(TScriptObject)
  // Symmetric matrices must never set the Transposed-flag
  private
    FTag: String;
    FTransposed,FSymmetric: Boolean;
    FDelegate: TDelegateMatrixRow;
    FId,FRow,FNTransposedDependencies,FNSymmetricDependencies: Integer;
  public
    Constructor Create(const Id: Integer);
    Procedure UpdateTag; virtual;
    Function GetValues(const Column: Integer): Float64; virtual; abstract;
    Destructor Destroy; override;
  public
    Property Id: Integer read FId;
    Property Tag: String read FTag write FTag;
    Property Row: Integer read FRow write FRow;
    Property Transposed: Boolean read FTransposed;
    Property Symmetric: Boolean read FSymmetric;
    Property Delegate: TDelegateMatrixRow read FDelegate;
    Property NTransposedDependencies: Integer read FNTransposedDependencies;
    Property NSymmetricDependencies: Integer read FNSymmetricDependencies;
  end;

  TConstantMatrixRow = Class(TScriptMatrixRow)
  private
    FValue: Float64;
  public
    Constructor Create(Id: Integer; Value: Float64);
    Function GetValues(const Column: Integer): Float64; override; final;
  public
    Property Value: Float64 read FValue;
  end;

  TTransposedMatrixRow = Class(TScriptMatrixRow)
  private
    Row: TScriptMatrixRow;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; MatrixRow: TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TMatrixRowsManipulation = Class(TScriptMatrixRow)
  strict protected
    Procedure Initialize;
    Function Dependencies(Dependency: Integer): TScriptObject; override; final;
    Function RowDependencies(Dependency: Integer): TScriptMatrixRow; virtual; abstract;
  end;

  TScaledMatrixRow = Class(TMatrixRowsManipulation)
  private
    Factor: Float64;
    Row: TScriptMatrixRow;
  strict protected
    Function RowDependencies(Dependency: Integer): TScriptMatrixRow; override; final;
  public
    Constructor Create(Id: Integer; ScaleFactor: Float64; MatrixRow: TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TMergedMatrixRow = Class(TMatrixRowsManipulation)
  private
    Rows: TArray<TScriptMatrixRow>;
  strict protected
    Function RowDependencies(Dependency: Integer): TScriptMatrixRow; override; final;
  public
    Constructor Create(Id: Integer; const MatrixRows: array of TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TScriptMatrixRow.Create(const Id: Integer);
begin
  inherited Create;
  FId := Id;
  FDelegate := TDelegateMatrixRow.Create(Size,
                Function(Column: Integer): Float64
                begin
                  Result := GetValues(Column);
                end );
end;

Procedure TScriptMatrixRow.UpdateTag;
begin
end;

Destructor TScriptMatrixRow.Destroy;
begin
  Delegate.Free;
  inherited Destroy;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TConstantMatrixRow.Create(Id: Integer; Value: Float64);
begin
  inherited Create(Id);
  FValue := Value;
  FSymmetric := true;
end;

Function TConstantMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := FValue;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TTransposedMatrixRow.Create(Id: Integer; MatrixRow: TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := 1;
  Row := MatrixRow;
  SetStage;
  if Row.FSymmetric then
  begin
    FSymmetric := true;
    FNSymmetricDependencies := 1;
  end else
  if Row.FTransposed then FNTransposedDependencies := 1 else FTransposed := true;
end;

Function TTransposedMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Row;
end;

Function TTransposedMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := Row.GetValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Function TMatrixRowsManipulation.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := RowDependencies(Dependency);
end;

Procedure TMatrixRowsManipulation.Initialize;
begin
  SetStage;
  // Count transposed and symmetrix dependencies
  for var Dependency := 0 to FNDependencies-1 do
  begin
    var Row := RowDependencies(Dependency);
    if Row.FTransposed then Inc(FNTransposedDependencies);
    if Row.FSymmetric then Inc(FNSymmetricDependencies);
  end;
  // Set transposed
  if FNTransposedDependencies > 0 then
  if FNTransposedDependencies+FNSymmetricDependencies = FNDependencies then
    FTransposed := true
  else
    raise Exception.Create('Inconsistent dependencies');
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TScaledMatrixRow.Create(Id: Integer; ScaleFactor: Float64; MatrixRow: TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := 1;
  Factor := ScaleFactor;
  Row := MatrixRow;
  Initialize;
end;

Function TScaledMatrixRow.RowDependencies(Dependency: Integer): TScriptMatrixRow;
begin
  Result := Row;
end;

Function TScaledMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := Factor*Row.GetValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMergedMatrixRow.Create(Id: Integer; const MatrixRows: array of TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := Length(MatrixRows);
  Rows := TArrayBuilder<TScriptMatrixRow>.Create(MatrixRows);
  Initialize;
end;

Function TMergedMatrixRow.RowDependencies(Dependency: Integer): TScriptMatrixRow;
begin
  Result := Rows[Dependency];
end;

Function TMergedMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := 0.0;
  for var Row := low(Rows) to high(Rows) do Result := Result + Rows[Row].GetValues(Column);
end;

end.
