unit Script.Objct.Info;

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
  SysUtils, Math, Ranges, ArrayBld, Log, Script.Objct, Script.Objct.Row;

Type
  TInfoLogger = Class(TStagedObject)
  private
    RowsSelection,ColumnsSelection: TRanges;
  protected
    Function FloatToStr(const Float: Float64): string;
  public
    Constructor Create(const Rows,Columns: TRanges);
    Function  RowsSelectionString: String;
    Function  ColumnsSelectionString: String;
    Procedure LogInfo; virtual; abstract;
  end;

  TCustomMatrixStatistics<StatsType: record> = Class(TInfoLogger)
  private
    Stats: StatsType;
    MatrixRows: TArray<TScriptMatrixRow>;
  strict protected
    Procedure Initialize(var Stats: StatsType); virtual; abstract;
    Procedure Update(MatrixId,Row,Column: Integer; Value: Float64; var Stats: StatsType); overload; virtual; abstract;
    Function Dependencies(Dependency: Integer): TScriptObject; override;
    Procedure LogInfo(Stats: StatsType); overload; virtual; abstract;
  public
    Constructor Create(const Matrices: array of TScriptMatrixRow); overload;
    Constructor Create(const Rows,Columns: TRanges; const Matrices: array of TScriptMatrixRow); overload;
    Procedure Update(Row: Integer); overload; override;
    Function  MatrixSelectionCount: Integer;
    Function  MatrixSelectionString: String;
    Procedure LogInfo; overload; override;
  end;

  TSumOfAbsoluteDifferences = Class(TInfoLogger)
  private
    MatrixRows: array[0..1] of TScriptMatrixRow;
    SumOfAbsoluteDifferences: Float64;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(const Rows,Columns: TRanges; const Matrix0,Matrix1: TScriptMatrixRow);
    Procedure Update(Row: Integer); override;
    Procedure LogInfo; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TInfoLogger.Create(const Rows,Columns: TRanges);
begin
  inherited Create;
  RowsSelection := Rows;
  ColumnsSelection := Columns;
end;

Function TInfoLogger.RowsSelectionString: String;
begin
  Result := RowsSelection.AsString;
end;

Function TInfoLogger.ColumnsSelectionString: String;
begin
  Result := ColumnsSelection.AsString;
end;

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

Constructor TCustomMatrixStatistics<StatsType>.Create(const Matrices: array of TScriptMatrixRow);
begin
  var Rows := TRanges.Create(TRange.Create(1,Size));
  var Columns := TRanges.Create(TRange.Create(1,Size));
  Create(Rows,Columns,Matrices);
end;

Constructor TCustomMatrixStatistics<StatsType>.Create(const Rows,Columns: TRanges;
                                                      const Matrices: array of TScriptMatrixRow);
begin
  inherited Create(Rows,Columns);
  Initialize(Stats);
  MatrixRows := TArrayBuilder<TScriptMatrixRow>.Create(Matrices);
  FNDependencies := Length(MatrixRows);
  SetStage;
end;

Function TCustomMatrixStatistics<StatsType>.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := MatrixRows[Dependency];
end;

Procedure TCustomMatrixStatistics<StatsType>.Update(Row: Integer);
begin
  if RowsSelection.Contains(Row+1) then
  for var Column := 0 to Size-1 do
  if ColumnsSelection.Contains(Column+1) then
  for var MatrixRow := low(MatrixRows) to high(MatrixRows) do
  begin
    var Id := MatrixRows[MatrixRow].Id;
    var Value := MatrixRows[MatrixRow].GetValues(Column);
    if MatrixRows[MatrixRow].Transposed then
      Update(Id,Column,Row,Value,Stats)
    else
      Update(Id,Row,Column,Value,Stats);
  end;
end;

Function TCustomMatrixStatistics<StatsType>.MatrixSelectionCount: Integer;
begin
  Result := Length(MatrixRows);
end;

Function TCustomMatrixStatistics<StatsType>.MatrixSelectionString: String;
Var
  Ids: array of Integer;
  MatrixIds: TRanges;
begin
  SetLength(Ids,MatrixSelectionCount);
  for var Mtrx := low(MatrixRows) to high(MatrixRows) do Ids[Mtrx] := MatrixRows[Mtrx].Id;
  MatrixIds := TRanges.Create(Ids);
  Result := MatrixIds.AsString;
end;

Procedure TCustomMatrixStatistics<StatsType>.LogInfo;
begin
  LogInfo(Stats);
end;

////////////////////////////////////////////////////////////////////////////////

Constructor TSumOfAbsoluteDifferences.Create(const Rows,Columns: TRanges; const Matrix0,Matrix1: TScriptMatrixRow);
begin
  inherited Create(Rows,Columns);
  MatrixRows[0] := Matrix0;
  MatrixRows[1] := Matrix1;
  FNDependencies := 2;
  SetStage;
end;

Function TSumOfAbsoluteDifferences.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := MatrixRows[Dependency];
end;

Procedure TSumOfAbsoluteDifferences.Update(Row: Integer);
begin
  if RowsSelection.Contains(Row+1) then
  for var Column := 0 to Size-1 do
  if ColumnsSelection.Contains(Column+1) then
  SumOfAbsoluteDifferences := SumOfAbsoluteDifferences +
    Abs(MatrixRows[0].GetValues(Column)-MatrixRows[1].GetValues(Column));
end;

Procedure TSumOfAbsoluteDifferences.LogInfo;
begin
  LogFile.Log;
  if MatrixRows[0].Id < MatrixRows[1].Id then
    LogFile.Log('Matrices: ' + MatrixRows[0].Id.ToString+','+MatrixRows[1].Id.ToString)
  else
    LogFile.Log('Matrices: ' + MatrixRows[1].Id.ToString+','+MatrixRows[0].Id.ToString);
  LogFile.Log('Rows: ' + RowsSelection.AsString);
  LogFile.Log('Columns: ' + ColumnsSelection.AsString);
  LogFile.Log('Sum of absolute differences: ' + FloatToStr(SumOfAbsoluteDifferences));
end;

end.
