unit Script.Objct;

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
  SysUtils;

Type
  TScriptObject = Class
  private
    FStage,ActiveStage: Integer;
    Function GetActive(Stage: integer): Boolean;
    Procedure SetActive(Stage: Integer; Active: Boolean);
    Function DependentsStage: Integer; virtual;
  strict protected
    FNDependencies: Integer;
    Procedure SetStage;
    Function Dependencies(Dependency: Integer): TScriptObject; virtual; abstract;
  public
    Class Var Size: Integer;
    Class Var MaxStage: Integer;
  public
    Constructor Create;
  public
    Property Stage: Integer read FStage;
    Property Active[Stage: Integer]: Boolean read GetActive write SetActive;
    Property NDependencies: Integer read FNDependencies;
  end;

  TStagedObject = Class(TScriptObject)
  // A script object that requires an iteration over all rows to obtain its result.
  // Script objects that depend on a staged oject can only use it in a subsequent
  // iteration (i.e. next stage) over all rows.
  private
    Function DependentsStage: Integer; override;
  public
    Procedure Update(Row: Integer); virtual; abstract;
  end;

////////////////////////////////////////////////////////////////////////////////
implementation
////////////////////////////////////////////////////////////////////////////////

Constructor TScriptObject.Create;
begin
  inherited Create;
  ActiveStage := -1;
end;

Function TScriptObject.GetActive(Stage: integer): Boolean;
begin
  Result := (ActiveStage = Stage);
end;

Procedure TScriptObject.SetActive(Stage: Integer; Active: Boolean);
begin
  if Active then
  begin
    ActiveStage := Stage;
    for var Dependency := 0 to FNDependencies-1 do
    begin
      var Dep := Dependencies(Dependency);
      if Dep.DependentsStage = Dep.FStage then Dep.SetActive(Stage,Active);
    end;
  end;
end;

Function TScriptObject.DependentsStage: Integer;
begin
  Result := FStage;
end;

Procedure TScriptObject.SetStage;
begin
  for var Dependency := 0 to FNDependencies-1 do
  begin
    var Stage := Dependencies(Dependency).DependentsStage;
    if Stage > FStage then FStage := Stage;
  end;
  if FStage > MaxStage then MaxStage := FStage;
end;

////////////////////////////////////////////////////////////////////////////////

Function TStagedObject.DependentsStage: Integer;
// Dependents must be in next stage
begin
  Result := FStage+1;
end;

end.
