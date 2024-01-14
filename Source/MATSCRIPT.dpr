program MATSCRIPT;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  SysUtils,
  Math,
  Propset,
  Script in 'Script.pas';

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
