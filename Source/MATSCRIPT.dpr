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
  KeyVal,
  MatrixScript in 'MatrixScript.pas',
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
    var ScriptInterpreter := TMatrixScriptInterpreter.Create;
    try
      var ScriptFileName := ExpandFileName(ParamStr(1));
      if FileExists(ScriptFileName) then
      begin
        // Set script parameters
        var ValidParameters := true;
        var ScriptParameters: TKeyValuePairs := nil;
        for var Parameter := 2 to ParamCount do
        begin
          var SeparatorPos := Pos('=',ParamStr(Parameter));
          if SeparatorPos > 1 then
            ScriptParameters.Append(Trim(Copy(ParamStr(Parameter),1,SeparatorPos-1)),
                                    Trim(Copy(ParamStr(Parameter),SeparatorPos+1,MaxInt)))
          else
            begin
              ValidParameters := false;
              writeln('Invalid script parameter (',ParamStr(Parameter),')');
            end;
        end;
        // Execute script
        if ValidParameters then
        begin
          FormatSettings.DecimalSeparator := '.';
          TKeyValuePairs.SetBaseDir(ExtractFileDir(ScriptFileName));
          ScriptInterpreter.Execute(ScriptFileName,ScriptParameters);
          if ScriptInterpreter.ErrorCount > 0 then ExitCode := 1;
        end else
          ExitCode := 1;
      end else
        begin
          writeln('Script file does not exist');
          ExitCode := 1;
        end;
    finally
      ScriptInterpreter.Free;
    end;
  end else
    begin
      writeln('Usage: ',ExtractFileName(ParamStr(0)),' "<script-file-name>" [<name>=<value> ...]');
      ExitCode := 1;
    end;
end.
