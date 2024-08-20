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
    Function FloatToStr(const Float: Float64): string;
  public
    Constructor Create(const Rows,Columns: TRanges);
    Procedure LogInfo; virtual; abstract;
  end;

  TMatrixStatistics = Class(TInfoLogger)
  private
    MatrixRows: TArray<TScriptMatrixRow>;
    LessThanZero,EqualToZero,GreaterThanZero,MinRow,MinColumn,MaxRow,MaxColumn: Integer;
    Min,Max,Diagonal,Total: Float64;
  strict protected
    Function Dependencies(Dependency: Integer): TScriptObject; override;
  public
    Constructor Create(const Rows,Columns: TRanges; const Matrices: array of TScriptMatrixRow);
    Procedure Update(Row: Integer); override;
    Procedure LogInfo; override;
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

Constructor TMatrixStatistics.Create(const Rows,Columns: TRanges; const Matrices: array of TScriptMatrixRow);
begin
  inherited Create(Rows,Columns);
  MatrixRows := TArrayBuilder<TScriptMatrixRow>.Create(Matrices);
  FNDependencies := Length(MatrixRows);
  SetStage;
  Min := Infinity;
  Max := NegInfinity;
end;

Function TMatrixStatistics.Dependencies(Dependency: Integer): TScriptObject;
begin
  Result := MatrixRows[Dependency];
end;

Procedure TMatrixStatistics.Update(Row: Integer);
begin
  if RowsSelection.Contains(Row) then
  for var Column := 0 to Size-1 do
  if ColumnsSelection.Contains(Column+1) then
  for var MatrixRow := low(MatrixRows) to high(MatrixRows) do
  begin
    // Update minimum and maximum value
    var Value := MatrixRows[MatrixRow].GetValues(Column);
    if Value < Min then
    begin
      Min := Value;
      MinRow := Row;
      MinColumn := Column+1;
    end;
    if Value > Max then
    begin
      Max := Value;
      MaxRow := Row;
      MaxColumn := Column+1;
    end;
    // Update cell counts
    if Value < 0 then Inc(LessThanZero) else
    if Value = 0 then Inc(EqualToZero) else
    Inc(GreaterThanZero);
    // Update (diagonal) total
    if Row = Column+1 then Diagonal := Diagonal + Value;
    Total := Total +Value;
  end;
end;

Procedure TMatrixStatistics.LogInfo;
Var
  Ids: array of Integer;
  MatrixIds: TRanges;
begin
  SetLength(Ids,Length(MatrixRows));
  for var Mtrx := low(MatrixRows) to high(MatrixRows) do Ids[Mtrx] := MatrixRows[Mtrx].Id;
  MatrixIds := TRanges.Create(Ids);

  LogFile.Log;
  LogFile.Log('Matrices: ' + MatrixIds.AsString);
  LogFile.Log('Rows: ' + RowsSelection.AsString);
  LogFile.Log('Columns: ' + ColumnsSelection.AsString);
  LogFile.Log('Minimum: ' + FloatToStr(Min) + ' (row='+ MinRow.ToString + '; column=' +
                                                          MinColumn.ToString + ')');
  LogFile.Log('Maximum: ' + FloatToStr(Max) + ' (row='+ MaxRow.ToString + '; column=' +
                                                          MaxColumn.ToString + ')');
  LogFile.Log('Cells < 0: ' + LessThanZero.ToString);
  LogFile.Log('Cells = 0: ' + EqualToZero.ToString);
  LogFile.Log('Cells > 0: ' + GreaterThanZero.ToString);
  LogFile.Log('Diagonal: ' + FloatToStr(Diagonal));
  LogFile.Log('Total: ' + FloatToStr(Total));
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
  if RowsSelection.Contains(Row) then
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
