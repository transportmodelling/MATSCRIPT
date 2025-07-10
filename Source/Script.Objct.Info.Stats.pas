unit Script.Objct.Info.Stats;

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
  SysUtils, Math, Log, Script.Objct.Info;

Type
  TMatrixStatistics = record
    LessThanZero,EqualToZero,GreaterThanZero,MinMatrix,MinRow,MinColumn,MaxMatrix,MaxRow,MaxColumn: Integer;
    Min,Max,Diagonal,Total: Float64;
  end;

  TMatrixStatisticsLogger = Class(TCustomMatrixStatistics<TMatrixStatistics>)
  strict protected
    Procedure Initialize(var Stats: TMatrixStatistics); override;
    Procedure Update(MatrixId,Row,Column: Integer; Value: Float64; var Stats: TMatrixStatistics); overload; override;
    Procedure LogInfo(Stats: TMatrixStatistics); overload; override;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Procedure TMatrixStatisticsLogger.Initialize(var Stats: TMatrixStatistics);
begin
  Stats.Min := Infinity;
  Stats.Max := NegInfinity;
end;

Procedure TMatrixStatisticsLogger.Update(MatrixId,Row,Column: Integer; Value: Float64; var Stats: TMatrixStatistics);
begin
  // Update minimum
  if Value < Stats.Min then
  begin
    Stats.Min := Value;
    Stats.MinMatrix := MatrixId;
    Stats.MinRow := Row;
    Stats.MinColumn := Column+1;
  end;
  // Update maximum
  if Value > Stats.Max then
  begin
    Stats.Max := Value;
    Stats.MaxMatrix := MatrixId;
    Stats.MaxRow := Row;
    Stats.MaxColumn := Column+1;
  end;
  // Update cell counts
  if Value < 0 then Inc(Stats.LessThanZero) else
  if Value = 0 then Inc(Stats.EqualToZero) else
  Inc(Stats.GreaterThanZero);
  // Update (diagonal) total
  if Row = Column+1 then Stats.Diagonal := Stats.Diagonal + Value;
  Stats.Total := Stats.Total + Value;
end;

Procedure TMatrixStatisticsLogger.LogInfo(Stats: TMatrixStatistics);
begin
  LogFile.Log;
  LogFile.Log('Matrices: ' + MatrixSelectionString);
  LogFile.Log('Rows: ' + RowsSelectionString);
  LogFile.Log('Columns: ' + ColumnsSelectionString);
  if MatrixSelectionCount = 1 then
  begin
    LogFile.Log('Minimum: ' + FloatToStr(Stats.Min) + ' (row='+ Stats.MinRow.ToString + '; ' +
                                                        'column=' + Stats.MinColumn.ToString + ')');
    LogFile.Log('Maximum: ' + FloatToStr(Stats.Max) + ' (row='+ Stats.MaxRow.ToString + '; ' +
                                                        'column=' + Stats.MaxColumn.ToString + ')');
  end else
  begin
    LogFile.Log('Minimum: ' + FloatToStr(Stats.Min) + ' (matrix='+ Stats.MinMatrix.ToString + '; ' +
                                                        'row=' + Stats.MinRow.ToString + '; ' +
                                                        'column=' + Stats.MinColumn.ToString + ')');
    LogFile.Log('Maximum: ' + FloatToStr(Stats.Max) + ' (matrix='+ Stats.MaxMatrix.ToString + '; ' +
                                                        'row=' + Stats.MaxRow.ToString + '; ' +
                                                        'column=' + Stats.MaxColumn.ToString + ')');
  end;
  LogFile.Log('Cells < 0: ' + Stats.LessThanZero.ToString);
  LogFile.Log('Cells = 0: ' + Stats.EqualToZero.ToString);
  LogFile.Log('Cells > 0: ' + Stats.GreaterThanZero.ToString);
  LogFile.Log('Diagonal: ' + FloatToStr(Stats.Diagonal));
  LogFile.Log('Total: ' + FloatToStr(Stats.Total));
end;

end.
