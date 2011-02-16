program PasMetricsConsole;

{$APPTYPE CONSOLE}

uses
  SysUtils, Classes, UFileLoader, UCompilerDefines, UASTNode,
  UMaintainabilityIndex, UParser, URuleType, ULexException, UParseException;

type
  TStyle = (
    sASCII,
    sCSV,
    sHTML
  );

var
  FFileName: string;
  FFile: TextFile;
  FStyle: TStyle;

procedure ParseParameters(out ADirectory: string; out ARecursive: Boolean);
var
  I: Integer;
  AFormat: string;
begin
  ADirectory := '';
  ARecursive := False;

  for I := 1 to ParamCount do
  begin
    if ParamStr(I) = '-r' then
      ARecursive := True
    else if (ParamStr(I)[1] = '-') and (ParamStr(I)[2] = 'o') then
    begin
      if (ParamStr(I)[3] = '=') then
        FFileName := Copy(ParamStr(I), 4, Length(ParamStr(I)) - 3);
    end
    else if (ParamStr(I)[1] = '-') and (ParamStr(I)[2] = 'f') then
    begin
      if (ParamStr(I)[3] = '=') then
        AFormat := UpperCase(Copy(ParamStr(I), 4, Length(ParamStr(I)) - 3));

      if (AFormat = 'CSV') then
        FStyle := sCSV
      else if (AFormat = 'HTML') then
        FStyle := sHTML
      else
        FStyle := sASCII;
    end
    else
    begin
      ADirectory := ParamStr(I);
      break;
    end;
  end;

  if ADirectory = '' then
    ADirectory := GetCurrentDir;

end;

procedure FindFiles(AFiles: TStringList; ADirectory, AFilter: string;
  ARecursive: Boolean);
var
  SR: TSearchRec;
  DirList: TStringList;
  IsFound: Boolean;
  i: integer;
begin
  if ADirectory[length(ADirectory)] <> '\' then
    ADirectory := ADirectory + '\';

  IsFound := FindFirst(ADirectory + AFilter, faAnyFile - faDirectory, SR) = 0;
  while IsFound do
  begin
    AFiles.Add(ADirectory + SR.Name);
    IsFound := FindNext(SR) = 0;
  end;
  FindClose(SR);

  if ARecursive then
  begin
    // Build a list of subdirectories
    DirList := TStringList.Create;
    IsFound := FindFirst(ADirectory + '*', faAnyFile, SR) = 0;
    while IsFound do
    begin
      if ((SR.Attr and faDirectory) <> 0) and (SR.Name[1] <> '.') then
        DirList.Add(ADirectory + SR.Name);

      IsFound := FindNext(SR) = 0;
    end;
    FindClose(SR);

    // Scan the list of subdirectories
    for i := 0 to DirList.Count - 1 do
      FindFiles(AFiles, DirList[i], AFilter, True);

    DirList.Free;
  end;
end;

function GetHeader: string;
begin
  case FStyle of
    sCSV: Result := 'File,MI,LOCpro';
    sHTML: Result := '<html><head><title>PasMetrics</title></head><body><table><tr><td>File</td><td>MI</td><td>LOCpro</td></tr>';
    else Result := '';
  end;
end;

function GetFooter: string;
begin
  case FStyle of
    sHTML: Result := '</table></body></html>';
    else Result := '';
  end;
end;

function GetResultFormat: string;
begin
  case FStyle of
    sCSV: Result := '%s,%.0f,%d';
    sHTML: Result := '<tr><td>%s</td><td>%.0f</td><td>%d</td></tr>';
    else Result := '%s - MI: %.0f - LOCpro: %d';
  end;
end;

function GetWarningFormat: string;
begin
  case FStyle of
    sCSV: Result := '%s,%s';
    sHTML: Result := '<tr><td>%s</td><td colspan="2">%s</td></tr>';
    else Result := '%s'#13#10'### Warning: %s';
  end;
end;

procedure OutputResult(AFilePath, ABaseDir: string; AMI: TMaintainabilityIndex);
begin
  WriteLn(FFile, Format(GetResultFormat,
    [ExtractRelativePath(ABaseDir, AFilePath), AMI.Value, AMI.LOCCounter.LOCProgram]));
end;

procedure OutputWarning(AFilePath, ABaseDir, AWarning: string);
begin
  WriteLn(FFile, Format(GetWarningFormat,
    [ExtractRelativePath(ABaseDir, AFilePath), AWarning]));
end;

procedure AnalyzeFile(AFilePath, ABaseDir: string);
var
  AFileLoader: TFileLoader;
  AContent: string;
  ACompilerDefines: TCompilerDefines;
  AParser: TParser;
  ANode: TASTNode;
  AMI: TMaintainabilityIndex;
begin
  // Create FileLoader to load the specified file
  AFileLoader := TFileLoader.Create;
  try
    // Load the file content
    AContent := AFileLoader.Load(AFilePath);
    // Create empty compiler defines
    ACompilerDefines := TCompilerDefines.Create;
    try
      try
      // Create the parser
      AParser := TParser.CreateFromText(AContent, '', ACompilerDefines, AFileLoader);
      try
        // Try to parse a unit from the file content
        ANode := AParser.ParseRule(RTGoal);
        try
          AMI := TMaintainabilityIndex.Create;
          AMI.Calculate(ANode);
          OutputResult(AFilePath, ABaseDir, AMI);
          AMI.Free;
        finally
          ANode.Free;
        end;
      finally
        AParser.Free;
      end;
      except
        on E: Exception do
          OutputWarning(AFilePath, ABaseDir, E.Message);
      end;
    finally
      ACompilerDefines.Free;
    end;
  finally
    AFileLoader.Free;
  end;
end;

procedure Main;
var
  ADirectory: string;
  ARecursive: Boolean;
  AFiles: TStringList;
  i: integer;
begin
  FStyle := sASCII;
  FFileName := '';
  ParseParameters(ADirectory, ARecursive);
  Assign(FFile, FFileName);
  Rewrite(FFile);

  if GetHeader <> '' then
    WriteLn(FFile, GetHeader);

  AFiles := TStringList.Create;
  FindFiles(AFiles, ADirectory, '*.pas', ARecursive);
  FindFiles(AFiles, ADirectory, '*.dpr', ARecursive);
  FindFiles(AFiles, ADirectory, '*.dpk', ARecursive);

  for i := 0 to AFiles.Count - 1 do
  begin
    AnalyzeFile(AFiles[i], ADirectory);
  end;

  if GetFooter <> '' then
    WriteLn(FFile, GetFooter);

  CloseFile(FFile);
  AFiles.Free;
end;

begin
  try
    Main;
  except
    on E: Exception do
      Writeln(E.Classname, ': ', E.Message);
  end;
end.
