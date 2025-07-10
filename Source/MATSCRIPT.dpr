program MATSCRIPT;

////////////////////////////////////////////////////////////////////////////////
//
// Author: Jaap Baak
// https://github.com/transportmodelling/MATSCRIPT
//
////////////////////////////////////////////////////////////////////////////////

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  Math,
  Propset,
  Script in 'Script.pas',
  Script.Objct in 'Script.Objct.pas',
  Script.Objct.Row in 'Script.Objct.Row.pas',
  Script.Objct.Mtrx in 'Script.Objct.Mtrx.pas',
  Script.Objct.Inp in 'Script.Objct.Inp.pas',
  Script.Objct.Info in 'Script.Objct.Info.pas',
  Script.Objct.Outp in 'Script.Objct.Outp.pas',
  Script.Objct.Info.Stats in 'Script.Objct.Info.Stats.pas',
  Script.Objct.Info.Totals in 'Script.Objct.Info.Totals.pas';

begin
  if ParamCount > 0 then
  begin
    var ScriptInterpreter := TScriptInterpreter.Create;
    try
      var ScriptFileName := ExpandFileName(ParamStr(1));
      if FileExists(ScriptFileName) then
      begin
        FormatSettings.DecimalSeparator := '.';
        TPropertySet.BaseDirectory := ExtractFileDir(ScriptFileName);
        ScriptInterpreter.Execute(ScriptFileName);
      end else
        writeln('Script file does not exist')
    finally
      ScriptInterpreter.Free;
    end;
  end else
    writeln('Usage: ',ExtractFileName(ParamStr(0)),' "<script-file-name>"');
end.
