unit TestMATSCRIPT.Row;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/MATSCRIPT
//
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
interface
////////////////////////////////////////////////////////////////////////////////

Uses
  SysUtils, Generics.Collections, DUnitX.TestFramework,
  Script.Objct, Script.Objct.Row, Script.Objct.Mtrx;

Type
  [TestFixture]
  TMatrixRowTests = Class
  // Tests the matrix row classes on 3x3 matrices, outside the script interpreter.
  private
    Const
      Tolerance = 1E-9;
    Var
      Objects: TObjectList<TObject>;
    Function Keep<T: class>(const Obj: T): T;
    Function MemMatrixReader(const Source: TScriptMatrixRow): TMemMatrixReader;
  public
    [Setup] Procedure Setup;
    [TearDown] Procedure TearDown;

    // Constant matrices
    [Test] Procedure Constant_SingleValue_FillsAllCells;
    [Test] Procedure Constant_TwoValues_FillsDiagonalAndOffDiagonal;

    // Derived matrices
    [Test] Procedure Scaled_Constant_MultipliesCells;
    [Test] Procedure Rounded_Constant_RoundsToDigits;
    [Test]
    [TestCase('Half','0.5,0,1')]
    [TestCase('OddHalf','1.5,0,2')]
    [TestCase('EvenHalf','2.5,0,3')]
    [TestCase('NegativeHalf','-0.5,0,-1')]
    [TestCase('NegativeEvenHalf','-2.5,0,-3')]
    [TestCase('DecimalHalf','0.25,1,0.3')]
    [TestCase('Large','1E9,10,1E9')]
    Procedure Rounded_Value_RoundsHalvesAwayFromZero(const Value: Float64; const Digits: Integer; const Expected: Float64);
    [Test] Procedure Merged_Constants_AddsCells;
    [Test] Procedure Product_Constants_MultipliesCells;
    [Test] Procedure Merged_SymmetricWithNonSymmetric_RaisesException;

    // Transposition flags
    [Test] Procedure Transposed_Symmetric_StaysSymmetric;
    [Test] Procedure Transposed_NonSymmetric_TogglesTransposed;

    // Memory matrices
    [Test] Procedure MemMatrixReader_UpdatedMatrix_ReadsCells;
    [Test] Procedure MemMatrixReader_StagedMatrix_UsesNextStage;
    [Test] Procedure MemMatrix_MemMatrixReaderSource_UsesReaderStage;

    // Activation
    [Test] Procedure Active_Dependent_ActivatesDependenciesUpToStagedObject;
    [Test] Procedure Active_LaterStage_EndsEarlierStage;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Function TMatrixRowTests.Keep<T>(const Obj: T): T;
// Registers an object for destruction at tear down
begin
  Objects.Add(Obj);
  Result := Obj;
end;

Function TMatrixRowTests.MemMatrixReader(const Source: TScriptMatrixRow): TMemMatrixReader;
// Creates a reader on the in-memory copy of the source matrix, with the copy
// updated for all rows of the source matrix.
begin
  var MemMatrix := Keep(TMemMatrix.Create([Source],moSum));
  var StagedObject: TStagedObject := MemMatrix;
  for var Row := 0 to TScriptObject.Size-1 do
  begin
    Source.Row := Row;
    StagedObject.Update(Row);
  end;
  Result := Keep(TMemMatrixReader.Create(2,MemMatrix));
end;

Procedure TMatrixRowTests.Setup;
begin
  TScriptObject.Size := 3;
  TScriptObject.MaxStage := 0;
  Objects := TObjectList<TObject>.Create;
end;

Procedure TMatrixRowTests.TearDown;
begin
  Objects.Free;
end;

Procedure TMatrixRowTests.Constant_SingleValue_FillsAllCells;
begin
  var Matrix := Keep(TConstantMatrixRow.Create(1,2.5));
  for var Row := 0 to TScriptObject.Size-1 do
  begin
    Matrix.Row := Row;
    for var Column := 0 to TScriptObject.Size-1 do Assert.AreEqual(2.5,Matrix.GetValues(Column),Tolerance);
  end;
  Assert.IsTrue(Matrix.Symmetric);
end;

Procedure TMatrixRowTests.Constant_TwoValues_FillsDiagonalAndOffDiagonal;
begin
  var Matrix := Keep(TConstantMatrixRow.Create(1,1.0,0.5));
  Matrix.Row := 1;
  Assert.AreEqual(0.5,Matrix.GetValues(0),Tolerance);
  Assert.AreEqual(1.0,Matrix.GetValues(1),Tolerance);
  Assert.AreEqual(0.5,Matrix.GetValues(2),Tolerance);
end;

Procedure TMatrixRowTests.Scaled_Constant_MultipliesCells;
begin
  var Source := Keep(TConstantMatrixRow.Create(1,2.0));
  var Matrix := Keep(TScaledMatrixRow.Create(2,3.0,Source));
  Assert.AreEqual(6.0,Matrix.GetValues(0),Tolerance);
  Assert.IsTrue(Matrix.Symmetric);
end;

Procedure TMatrixRowTests.Rounded_Constant_RoundsToDigits;
begin
  var Source := Keep(TConstantMatrixRow.Create(1,1.26));
  var Matrix := Keep(TRoundedMatrixRow.Create(2,1,Source));
  Assert.AreEqual(1.3,Matrix.GetValues(0),Tolerance);
end;

Procedure TMatrixRowTests.Rounded_Value_RoundsHalvesAwayFromZero(const Value: Float64; const Digits: Integer; const Expected: Float64);
begin
  var Source := Keep(TConstantMatrixRow.Create(1,Value));
  var Matrix := Keep(TRoundedMatrixRow.Create(2,Digits,Source));
  Assert.AreEqual(Expected,Matrix.GetValues(0),Tolerance);
end;

Procedure TMatrixRowTests.Merged_Constants_AddsCells;
begin
  var Source0 := Keep(TConstantMatrixRow.Create(1,2.0));
  var Source1 := Keep(TConstantMatrixRow.Create(2,0.5));
  var Matrix := Keep(TMergedMatrixRow.Create(3,true,false,[Source0,Source1]));
  Assert.AreEqual(2.5,Matrix.GetValues(0),Tolerance);
  Assert.IsTrue(Matrix.Symmetric);
end;

Procedure TMatrixRowTests.Product_Constants_MultipliesCells;
begin
  var Source0 := Keep(TConstantMatrixRow.Create(1,2.0));
  var Source1 := Keep(TConstantMatrixRow.Create(2,3.0));
  var Matrix := Keep(TProductMatrixRow.Create(3,true,false,[Source0,Source1]));
  Assert.AreEqual(6.0,Matrix.GetValues(0),Tolerance);
  Assert.IsTrue(Matrix.Symmetric);
end;

Procedure TMatrixRowTests.Merged_SymmetricWithNonSymmetric_RaisesException;
begin
  var Reader := MemMatrixReader(Keep(TConstantMatrixRow.Create(1,1.0)));
  Assert.WillRaiseWithMessage(Procedure
                              begin
                                TMergedMatrixRow.Create(3,true,false,[Reader]).Free;
                              end,
                              Exception,'Matrix must be symmetric');
end;

Procedure TMatrixRowTests.Transposed_Symmetric_StaysSymmetric;
begin
  var Source := Keep(TConstantMatrixRow.Create(1,1.0));
  var Matrix := Keep(TTransposedMatrixRow.Create(2,Source));
  Assert.IsTrue(Matrix.Symmetric);
  Assert.IsFalse(Matrix.Transposed);
end;

Procedure TMatrixRowTests.Transposed_NonSymmetric_TogglesTransposed;
begin
  var Reader := MemMatrixReader(Keep(TConstantMatrixRow.Create(1,1.0)));
  var Transposed := Keep(TTransposedMatrixRow.Create(3,Reader));
  var TransposedTwice := Keep(TTransposedMatrixRow.Create(4,Transposed));
  Assert.IsFalse(Reader.Symmetric);
  Assert.IsTrue(Transposed.Transposed);
  Assert.IsFalse(TransposedTwice.Transposed);
end;

Procedure TMatrixRowTests.MemMatrixReader_UpdatedMatrix_ReadsCells;
begin
  var Reader := MemMatrixReader(Keep(TConstantMatrixRow.Create(1,1.0,0.5)));
  Reader.Row := 1;
  Assert.AreEqual(0.5,Reader.GetValues(0),Tolerance);
  Assert.AreEqual(1.0,Reader.GetValues(1),Tolerance);
  Assert.AreEqual(0.5,Reader.GetValues(2),Tolerance);
end;

Procedure TMatrixRowTests.MemMatrixReader_StagedMatrix_UsesNextStage;
begin
  var Source := Keep(TConstantMatrixRow.Create(1,1.0));
  var MemMatrix := Keep(TMemMatrix.Create([Source],moSum));
  var Reader := Keep(TMemMatrixReader.Create(2,MemMatrix));
  Assert.AreEqual(0,MemMatrix.Stage);
  Assert.AreEqual(1,Reader.Stage);
  Assert.AreEqual(1,TScriptObject.MaxStage);
end;

Procedure TMatrixRowTests.MemMatrix_MemMatrixReaderSource_UsesReaderStage;
// A memory matrix that reads another memory matrix can only be updated once
// the other memory matrix is complete, so in the stage of its reader
begin
  var Source := Keep(TConstantMatrixRow.Create(1,1.0));
  var MemMatrix := Keep(TMemMatrix.Create([Source],moSum));
  var Reader := Keep(TMemMatrixReader.Create(2,MemMatrix));
  var NextMemMatrix := Keep(TMemMatrix.Create([Reader],moSum));
  var NextReader := Keep(TMemMatrixReader.Create(3,NextMemMatrix));
  Assert.AreEqual(1,NextMemMatrix.Stage);
  Assert.AreEqual(2,NextReader.Stage);
  Assert.AreEqual(2,TScriptObject.MaxStage);
end;

Procedure TMatrixRowTests.Active_Dependent_ActivatesDependenciesUpToStagedObject;
// The memory matrix is filled in stage 0, so activating its reader for stage 1
// leaves the memory matrix and its source inactive
begin
  var Source := Keep(TConstantMatrixRow.Create(1,1.0));
  var MemMatrix := Keep(TMemMatrix.Create([Source],moSum));
  var Reader := Keep(TMemMatrixReader.Create(2,MemMatrix));
  var Scaled := Keep(TScaledMatrixRow.Create(3,2.0,Reader));
  Scaled.Active[1] := true;
  Assert.IsTrue(Scaled.Active[1],'Scaled');
  Assert.IsTrue(Reader.Active[1],'Reader');
  Assert.IsFalse(MemMatrix.Active[1],'Memory matrix');
  Assert.IsFalse(Source.Active[1],'Source');
end;

Procedure TMatrixRowTests.Active_LaterStage_EndsEarlierStage;
begin
  var Source := Keep(TConstantMatrixRow.Create(1,1.0));
  var Scaled := Keep(TScaledMatrixRow.Create(2,2.0,Source));
  Scaled.Active[0] := true;
  Scaled.Active[1] := true;
  Assert.IsFalse(Scaled.Active[0],'Scaled in stage 0');
  Assert.IsTrue(Scaled.Active[1],'Scaled in stage 1');
  Assert.IsFalse(Source.Active[0],'Source in stage 0');
  Assert.IsTrue(Source.Active[1],'Source in stage 1');
end;

initialization
  TDUnitX.RegisterTestFixture(TMatrixRowTests);
end.
