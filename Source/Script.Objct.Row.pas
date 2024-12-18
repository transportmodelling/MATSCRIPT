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
    FDelegate: TDelegatedMatrixRow;
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
    Property Delegate: TDelegatedMatrixRow read FDelegate;
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
  private
    Factor: Float64;
    Row: TScriptMatrixRow;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; NDigits: Byte; MatrixRow: TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TMergedMatrixRow = Class(TScriptMatrixRow)
  private
    Rows: TArray<TScriptMatrixRow>;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; Symmetric,Transposed: Boolean; const MatrixRows: array of TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

  TProductMatrixRow = Class(TScriptMatrixRow)
  private
    Rows: TArray<TScriptMatrixRow>;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(Id: Integer; Symmetric,Transposed: Boolean; const MatrixRows: array of TScriptMatrixRow);
    Function GetValues(const Column: Integer): Float64; override; final;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TScriptMatrixRow.Create(const Id: Integer);
begin
  inherited Create;
  FId := Id;
  FDelegate := TDelegatedMatrixRow.Create(Size,
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
begin
  Result := Round(Factor*Row.GetValues(Column))/Factor;
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TMergedMatrixRow.Create(Id: Integer; Symmetric,Transposed: Boolean; const MatrixRows: array of TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := Length(MatrixRows);
  if Symmetric then FSymmetric := true else FTransposed := Transposed;
  // Set Rows and check Symmetric and Transposed-flags
  SetLength(Rows,FNDependencies);
  for var Row := low(MatrixRows) to high(MatrixRows) do
  begin
    Rows[Row] := MatrixRows[Row];
    if Symmetric and not Rows[Row].Symmetric then raise Exception.Create('Matrix must be symmetric');
    if Transposed and not (Rows[Row].Symmetric or Rows[Row].Transposed) then raise Exception.Create('Matrix must be transposed');
    if not Transposed and Rows[Row].Transposed then raise Exception.Create('Matrix must not be transposed');
  end;
  SetStage;
end;

Function TMergedMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Rows[Dependency];
end;

Function TMergedMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := 0.0;
  for var Row := low(Rows) to high(Rows) do Result := Result + Rows[Row].GetValues(Column);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TProductMatrixRow.Create(Id: Integer; Symmetric,Transposed: Boolean; const MatrixRows: array of TScriptMatrixRow);
begin
  inherited Create(Id);
  FNDependencies := Length(MatrixRows);
  if Symmetric then FSymmetric := true else FTransposed := Transposed;
  // Set Rows and check Symmetric and Transposed-flags
  SetLength(Rows,FNDependencies);
  for var Row := low(MatrixRows) to high(MatrixRows) do
  begin
    Rows[Row] := MatrixRows[Row];
    if Symmetric and not Rows[Row].Symmetric then raise Exception.Create('Matrix must be symmetric');
    if Transposed and not (Rows[Row].Symmetric or Rows[Row].Transposed) then raise Exception.Create('Matrix must be transposed');
    if not Transposed and Rows[Row].Transposed then raise Exception.Create('Matrix must not be transposed');
  end;
  SetStage;
end;

Function TProductMatrixRow.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := Rows[Dependency];
end;

Function TProductMatrixRow.GetValues(const Column: Integer): Float64;
begin
  Result := 1.0;
  for var Row := low(Rows) to high(Rows) do Result := Result*Rows[Row].GetValues(Column);
end;

end.
