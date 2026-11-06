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
  SysUtils, ArrBld, matio, matio.row, Script.Objct;

Type
  TScriptMatrixRow = Class(TScriptObject)
  // Symmetric matrices must never set the Transposed-flag
  private
    FTag: String;
    FTransposed,FSymmetric: Boolean;
    FDelegate: TGetterMatrixRow;
    FId,FRow: Integer;
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
    Property Delegate: TGetterMatrixRow read FDelegate;
  end;

  TConstantMatrixRow = Class(TScriptMatrixRow)
  private
    FDiagonalValue,FOffDiagonalValue: Float64;
  public
    Constructor Create(Id: Integer; Value: Float64); overload;
    Constructor Create(Id: Integer; DiagonalValue,OffDiagonalValue: Float64); overload;
    Function GetValues(const Column: Integer): Float64; override; final;
  public
    Property DiagonalValue: Float64 read FDiagonalValue;
    Property OffDiagonalValue: Float64 read FOffDiagonalValue;
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

  TScaledMatrixRow = Class(TScriptMatrixRow)
  private
    Factor: Float64;
    Row: TScriptMatrixRow;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; ScaleFactor: Float64; MatrixRow: TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TRoundedMatrixRow = Class(TScriptMatrixRow)
  public
    Const
      // Float64 holds about 15 significant decimal digits
      MaxDigits = 15;
  private
    Factor: Float64;
    Row: TScriptMatrixRow;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; NDigits: Byte; MatrixRow: TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TCustomCombinedMatrixRow = Class(TScriptMatrixRow)
  // Combines the cells of several matrix rows; descendants combine them by an operation
  private
    Function OrientationError(const MatrixRow: TScriptMatrixRow): String;
  strict protected
    Rows: TArray<TScriptMatrixRow>;
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; Symmetric,Transposed: Boolean; const MatrixRows: array of TScriptMatrixRow);
  end;

  TCombinedMatrixRowClass = Class of TCustomCombinedMatrixRow;

  TMergedMatrixRow = Class(TCustomCombinedMatrixRow)
  public
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TProductMatrixRow = Class(TCustomCombinedMatrixRow)
  public
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TScriptMatrixRow.Create(const Id: Integer);
begin
  inherited Create;
  FId := Id;
  FDelegate := TGetterMatrixRow.Create(Size,
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
  Create(Id,Value,Value);
end;

Constructor TConstantMatrixRow.Create(Id: Integer; DiagonalValue,OffDiagonalValue: Float64);
begin
  inherited Create(Id);
  FDiagonalValue := DiagonalValue;
  FOffDiagonalValue := OffDiagonalValue;
  FSymmetric := true;
end;

Function TConstantMatrixRow.GetValues(const Column: Integer): Float64;
begin
  if Row = Column then
    Result := FDiagonalValue
  else
    Result := FOffDiagonalValue
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TTransposedMatrixRow.Create(Id: Integer; MatrixRow: TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := 1;
  Row := MatrixRow;
  if Row.FSymmetric then FSymmetric := true else FTransposed := not Row.FTransposed;
  SetStage;
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

Constructor TScaledMatrixRow.Create(Id: Integer; ScaleFactor: Float64; MatrixRow: TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := 1;
  FSymmetric := MatrixRow.FSymmetric;
  FTransposed := MatrixRow.FTransposed;
  Factor := ScaleFactor;
  Row := MatrixRow;
  SetStage;
end;

Function TScaledMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Row;
end;

Function TScaledMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := Factor*Row.GetValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TRoundedMatrixRow.Create(Id: Integer; NDigits: Byte; MatrixRow: TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := 1;
  FSymmetric := MatrixRow.FSymmetric;
  FTransposed := MatrixRow.FTransposed;
  Factor := 1.0;
  for var Digit := 1 to NDigits do Factor := 10*Factor;
  Row := MatrixRow;
  SetStage;
end;

Function TRoundedMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Row;
end;

Function TRoundedMatrixRow.GetValues(const Column: Integer): Float64;
// Halves are rounded away from zero. Int keeps the rounding in Float64, which
// holds any scaled value, where an Int64 overflows beyond about 9.2E18.
begin
  var Value: Float64 := Factor*Row.GetValues(Column);
  if Value < 0 then
    Result := -Int(0.5-Value)/Factor
  else
    Result := Int(Value+0.5)/Factor;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TCustomCombinedMatrixRow.Create(Id: Integer; Symmetric,Transposed: Boolean; const MatrixRows: array of TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := Length(MatrixRows);
  if Symmetric then FSymmetric := true else FTransposed := Transposed;
  // Set Rows and check Symmetric and Transposed-flags
  SetLength(Rows,FNDependencies);
  for var Row := low(MatrixRows) to high(MatrixRows) do
  begin
    var Error := OrientationError(MatrixRows[Row]);
    if Error = '' then
      Rows[Row] := MatrixRows[Row]
    else
      raise Exception.Create(Error);
  end;
  SetStage;
end;

Function TCustomCombinedMatrixRow.OrientationError(const MatrixRow: TScriptMatrixRow): String;
// Why the orientation of a matrix row does not fit this combined matrix row;
// empty when it fits
begin
  if FSymmetric and not MatrixRow.Symmetric then
    Result := 'Matrix must be symmetric'
  else if FTransposed and not (MatrixRow.Symmetric or MatrixRow.Transposed) then
    Result := 'Matrix must be transposed'
  else if not FTransposed and MatrixRow.Transposed then
    Result := 'Matrix must not be transposed'
  else
    Result := '';
end;

Function TCustomCombinedMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Rows[Dependency];
end;

////////////////////////////////////////////////////////////////////////////////

Function TMergedMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := 0.0;
  for var Row := low(Rows) to high(Rows) do Result := Result + Rows[Row].GetValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Function TProductMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := 1.0;
  for var Row := low(Rows) to high(Rows) do Result := Result*Rows[Row].GetValues(Column);
end;

end.
