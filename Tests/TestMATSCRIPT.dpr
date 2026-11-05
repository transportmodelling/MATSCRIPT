program TestMATSCRIPT;

////////////////////////////////////////////////////////////////////////////////
//
// https://github.com/transportmodelling/MATSCRIPT
//
////////////////////////////////////////////////////////////////////////////////

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.Loggers.Xml.JUnit,
  DUnitX.TestFramework,
  TestMATSCRIPT.Row in 'TestMATSCRIPT.Row.pas',
  TestMATSCRIPT.Interpreter in 'TestMATSCRIPT.Interpreter.pas';

begin
  try
    // Initialization
    TDUnitX.CheckCommandLine;
    TDUnitX.Options.XMLOutputFile := ExtractFilePath(ParamStr(0)) + 'TestMATSCRIPT.xml';
    // Script values use a point as decimal separator, as in the MATSCRIPT program
    FormatSettings.DecimalSeparator := '.';
    // Create the test Runner
    var Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Runner.FailsOnNoAsserts := False;
    // Create loggers
    var ConsoleLogger := TDUnitXConsoleLogger.Create(false);
    var NunitLogger := TDUnitXXMLJUnitFileLogger.Create(TDUnitX.Options.XMLOutputFile);
    Runner.AddLogger(ConsoleLogger);
    Runner.AddLogger(NunitLogger);
    // Run tests
    var Results := Runner.Execute;
    if not Results.AllPassed then System.ExitCode := EXIT_ERRORS;
  except
    on E: Exception do
    begin
      System.Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := EXIT_ERRORS;
    end;
  end;
end.
