unit Script.Objct.Info.Totals;

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
  SysUtils, Classes, Math, Log, FloatHlp,ArrayHlp, Parse, Script.Objct.Row, Script.Objct.Info;

Type
  TMatrixTotals = record
    RowTotals,ColumnTotals: TArray<Float64>;
  end;

  TMatrixTotalsLogger = Class(TCustomMatrixStatistics<TMatrixTotals>)
  private
    FFileName: TFileName;
    FDelimiter: TDelimiter;
  strict protected
    Procedure Initialize(var Totals: TMatrixTotals); override;
    Procedure Update(MatrixId,Row,Column: Integer; Value: Float64; var Totals: TMatrixTotals); overload; override;
    Procedure LogInfo(Totals: TMatrixTotals); overload; override;
  public
    Constructor Create(const FileName: TFileName; Delimiter: TDelimiter; const Matrices: array of TScriptMatrixRow);
  public
    Property FileName: TFileName read FFileName;
    Property Delimiter: TDelimiter read FDelimiter;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TMatrixTotalsLogger.Create(const FileName: TFileName; Delimiter: TDelimiter; const Matrices: array of TScriptMatrixRow);
begin
  inherited Create(Matrices);
  FFileName := FileName;
  FDelimiter := Delimiter;
end;

Procedure TMatrixTotalsLogger.Initialize(var Totals: TMatrixTotals);
begin
  Totals.RowTotals.Length := Size;
  Totals.ColumnTotals.Length := Size;
end;

Procedure TMatrixTotalsLogger.Update(MatrixId,Row,Column: Integer; Value: Float64; var Totals: TMatrixTotals);
begin
  Totals.RowTotals[Row].Add(Value);
  Totals.ColumnTotals[column].Add(Value);
end;

Procedure TMatrixTotalsLogger.LogInfo(Totals: TMatrixTotals);
begin
  var Writer := TStreamWriter.Create(FFileName);
  try
    for var Index := 0 to Size-1 do
    begin
      Writer.Write(Index+1);
      Writer.Write(FDelimiter.Delimiter);
      Writer.Write(FloatToStr(Totals.RowTotals[Index]));
      Writer.Write(FDelimiter.Delimiter);
      Writer.Write(FloatToStr(Totals.ColumnTotals[Index]));
      Writer.WriteLine;
    end;
  finally
    Writer.Free;
  end;
end;

end.
