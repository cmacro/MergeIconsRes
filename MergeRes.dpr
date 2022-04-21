program MergeRes;


{$APPTYPE CONSOLE}

{$R *.res}

uses
  Winapi.Windows,
  Classes,
  vcl.Graphics,
  SysUtils,
  //pngimage,
  ZLib,
  Vcl.Imaging.pngimage;

const
  MSG_NONAMES = '没有资源图标文件名称列表';

type
  TPrintProc = procedure (const AVal: string) of object;

  TDataType = (dtIconMerge, dtPngPack);

  TParams = class
  private
    SrouceData: string;
    OutFileName: string;
    Kind: TDataType;
    FileList: TStringList;
    ResPrefix : string;

    procedure ReadDirFiles;
    procedure ReadFileName;
    function LoadParams: Boolean;
    constructor Create;
    destructor Destroy; override;
    procedure BuildOutFileName(const s: string);
    procedure LoadImageNames(const ASrcCfg: string);
  end;

  TConvertRes = class
  private
    FParams: TParams;
    FIconMap: TBitmap;
    FOnLogEvent: TPrintProc;
    procedure BuildMap(w, h:Integer);
    procedure AddLog(const AMsg: string);
  public
    destructor Destroy; override;
    constructor Create(AFiles: TParams); virtual;

    function Exec(PrintMsg: TPrintProc): Boolean; virtual; abstract;
    function Save(const AOutFileName: string): Boolean; virtual;

    property ResMap: TBitmap read FIconMap;
    property OnLogEvent: TPrintProc read FOnLogEvent write FOnLogEvent;
  end;

  TPngPack = class(TConvertRes)
  public
    function Exec(PrintMsg: TPrintProc): Boolean; override;
  end;


  TIconItem = record
    name: string;
    ID: string;
    comment: string;
  end;

  TMergeIcons = class(TConvertRes)
  private
    FIcon: TPngImage;
    FRowCnt: Integer;
    FColCnt: Integer;
    //FFiles: TStringList;
    FSource: array of TIconItem;
    FSourceCount: Integer;
    FWidth: integer;
    FHeight: integer;
    FIconPrefix: string;

    procedure BuildIconsID;
    procedure BuildResMap;
    function GetCount: Integer;
    function GetFileNames(Index: Integer): string;
    function LoadIcon(AIndex: Integer): Boolean;
    function LoadImageNames: Boolean;
    function MergeIcon(AIndex: Integer): Boolean;
    procedure SaveResIconIndexDefine(const AFileName: string);
    function ExtractRecName(s: string): string;
  public
    destructor Destroy; override;
    function Save(const AOutFileName: string): Boolean; override;
    property Count: Integer read GetCount;
    property FileNames[Index: Integer]: string read GetFileNames;
    property IconPrefix: string read FIconPrefix write FIconPrefix;

    function Exec(PrintMsg: TPrintProc): Boolean; override;

  end;

  TMergeSrv = class
  private
    FLog: TStringList;
    FDataFile: TParams;
    procedure PrintHelp;
    procedure PrintLog;
    procedure PrintMsg(const Afmt: string; const Args: array of const); overload;
    procedure PrintMsg(const AVal: string); overload;
    procedure DoOnAddLog(const AMsg: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Exec;
  end;

constructor TMergeSrv.Create;
begin
  FDataFile := TParams.Create;
  FLog := TStringList.Create;
end;

destructor TMergeSrv.Destroy;
begin
  FDataFile.free;
  FLog.free;
  inherited;
end;

procedure TMergeSrv.DoOnAddLog(const AMsg: string);
begin
  FLog.Add(AMsg);
end;

procedure TMergeSrv.Exec;
var
  cConvert: TConvertRes;
begin
  if FDataFile.LoadParams then
  begin

    case FDataFile.Kind of
      dtIconMerge : cConvert := TMergeIcons.Create(FDataFile);
      dtPngPack   : cConvert := TPngPack.Create(FDataFile);
      else          cConvert := nil;
    end;

    if cConvert <> nil then
    begin
      cConvert.OnLogEvent := DoOnAddLog;
      try
        PrintMsg('');
        PrintMsg('Start %s', [FDataFile.SrouceData]);
        //PrintMsg('_______________________________________');
        if cConvert.Exec(PrintMsg) then
          if cConvert.Save(FDataFile.OutFileName) then
          begin
            PrintMsg('_______________________________________');
            PrintMsg(format('Finish: %s',[ChangeFileExt(FDataFile.OutFileName, '.IconPack')]));
            PrintLog;
          end;
      finally
        cConvert.Free;
      end;
    end
    else
      PrintMsg('Err: ' + MSG_NONAMES);
  end
  else
    PrintHelp;
end;

procedure TMergeSrv.PrintHelp;
begin
  PrintMsg('合并参数：');
  PrintMsg('----------------------------------');
  PrintMsg('%s <-s [dir | file]> [-o outfile] [-p prefix]', [ExtractFileName(ParamStr(0))]);
  PrintMsg('  -s source files');
  PrintMsg('  -o output filename');
  PrintMsg('  -p prefix');
end;

procedure TMergeSrv.PrintLog;
var
  I: Integer;
begin
  for I := 0 to FLog.Count - 1 do
    PrintMsg(FLog[i]);
end;

procedure TMergeSrv.PrintMsg(const Afmt: string; const Args: array of const);
begin
  PrintMsg(format(Afmt, Args));
end;

procedure TMergeSrv.PrintMsg(const AVal: string);
begin
  Writeln(AVal);
end;

constructor TParams.Create;
begin
  Kind := dtIconMerge;
  FileList := TStringList.Create;
end;

destructor TParams.Destroy;
begin
  FileList.Free;
  inherited;
end;

procedure TParams.BuildOutFileName(const s: string);
var
  sFileName: string;
begin
  sFileName := s;
  if (sFileName <> '') then
  begin
    if (sFileName[Length(sFileName)] = '\') then
      sFileName := Format('%s%s',[sFileName, ExtractFileName(SrouceData)])
    else if Pos('\', sFileName) > 0 then
    begin
      if not DirectoryExists(ExtractFilePath(sFileName)) then
        if not CreateDir(ExtractFilePath(sFileName)) then
          sFileName := '';
    end;
  end;

  if sFileName = '' then
    sFileName := SrouceData;
  if sFileName = '' then
    sFileName := 'out';

  if FileExists(sFileName) then
    sFileName := ChangeFileExt(sFileName, '.bmp')
  else
    sFileName := sFileName + '.bmp';

  OutFileName := ExpandFileName(sFileName);
end;

procedure TParams.LoadImageNames(const ASrcCfg: string);
var
  I: Integer;
  sVal: string;
  cDatas: TStringList;
  iCommentPos: Integer;
  idx: Integer;
begin
  cDatas := TStringList.Create;
  try
    cDatas.LoadFromFile(ASrcCfg);
    for I := 0 to cDatas.Count - 1 do
    begin
      sVal := Trim(cDatas[i]);
      // 去除注释行和空白行
      if (sVal = '') or (sVal[1] = ';') or (sVal[1] = '/') then
        sVal := '';

      /// 清除后面的注释和空格
      iCommentPos := 0;
      if sVal <> '' then
        for idx := 1 to Length(sVal) do
          if CharInSet(sVal[idx], [#9, ',', ';']) then
          begin
            iCommentPos := idx;
            Break;
          end;


      if iCommentPos = 1 then sVal := ''
      else if (sVal <> '') and (iCommentPos > 1) then
        sVal := Trim(Copy(sval, 1, iCommentPos - 1));

      if (sVal <> '') and FileExists(sVal) then
        FileList.Add(ExpandFileName(sVal));
    end;
  finally
    cDatas.Free;
  end;
end;

function TParams.LoadParams: Boolean;
var
  I: Integer;
  s, t: string;
  sOutFile: string;
begin
  Kind := dtIconMerge;

  t := '';
  s := '';

  sOutFile := '';
  SrouceData := '';
  ResPrefix := '';

  for I := 1 to ParamCount do
  begin
    s := ParamStr(i);
    if s = '' then Continue;
    if s[1] = '-' then
    begin
      t := s;
      Continue;
    end;

    if t = '-s' then SrouceData := s
    else if t = '-p' then ResPrefix := s
    else if t = '-o' then sOutFile := s;

    t := '';
    s := '';
  end;

  if SrouceData = '' then
  begin
    if ParamCount >= 1 then SrouceData := Trim(ParamStr(1))
    else  SrouceData := ChangeFileExt(ParamStr(0), '.lst');
  end;

  if FileExists(SrouceData) then
    ReadFileName
  else if DirectoryExists(SrouceData) then
    ReadDirFiles;

  BuildOutFileName(sOutFile);

  Result := (FileList.Count > 0) and (OutFileName <> '');
end;

procedure TParams.ReadDirFiles;
var
  sr: TSearchRec;
  i: Integer;
  sPath: string;
begin
  sPath := SrouceData;
  if not DirectoryExists(sPath) then
    Exit;

  if sPath[Length(sPath)] <> '\' then
    sPath := sPath + '\';

  i := FindFirst(sPath + '*.png', faAnyFile, sr);
  try
    while i = 0 do
    begin
      FileList.Add(sPath + sr.Name);
      i := FindNext(sr);
    end;
  finally
    FindClose(sr);
  end;
end;

procedure TParams.ReadFileName;
begin
  if SrouceData <> '' then
  begin
    SetCurrentDir(ExtractFilePath(SrouceData));
    LoadImageNames(SrouceData);
  end;

  if SameText(ExtractFileExt(SrouceData), '.lst') then
    Kind := dtIconMerge
  else
    Kind := dtPngPack;
end;

procedure TMergeIcons.BuildResMap;
var
  bExists: Boolean;
  I: Integer;
begin
  // 预读文件尺寸
  FIcon := TPngImage.Create;
  bExists := False;
  for I := 0 to Count - 1 do
  begin
    bExists := LoadIcon(0);
    if bExists then
      Break;
  end;

  if not bExists then
    Exit;

  FColCnt := 10;
  FRowCnt := Count div FColCnt;
  if Count mod FColCnt > 0 then
    inc(FRowCnt);

  FWidth := FIcon.Width;
  FHeight:= FIcon.Height;

  BuildMap(FWidth * FColCnt, FHeight * FRowCnt);
end;

destructor TMergeIcons.Destroy;
begin
  if FIcon <> nil then  FIcon.free;
  inherited;
end;


function TMergeIcons.ExtractRecName(s: string): string;
var
  i: Integer;
begin
  s := ExtractFileName(s);
  i := Pos('.', s);
  if i > 0 then
    delete(s, i, Length(s));

  for I := 1 to Length(s) do
    if (s[i] = ' ') or (s[i] = '-') then
      s[i] := '_';

  Result := s;
end;

procedure TMergeIcons.BuildIconsID;

var
  I: Integer;
  iSameCnt: Integer;
  iSearch: Integer;
  sPrefix: string;
begin
  if Count = 0 then
    Exit;

  sPrefix := '';
  if assigned(FParams) then
    sPrefix := FParams.ResPrefix;

  for I := 0 to count - 1 do
    FSource[I].ID := 'IDI_' + sPrefix + ExtractRecName(FSource[i].name);

  for iSearch := 0 to count - 2 do
  begin
    iSameCnt := 0;
    for I := iSearch + 1 to count - 1 do
      if SameText(FSource[i].ID, FSource[iSearch].ID) then
      begin
        inc(iSameCnt);
        FSource[i].ID := format('%s_%d', [FSource[i].ID, iSameCnt]);
        FSource[i].comment := format('%s 图标被重复定义，和%d名称相同', [FSource[i].comment, iSearch]);
      end;
  end;
end;

function TMergeIcons.Exec(PrintMsg: TPrintProc): Boolean;
var
  I: Integer;
  iErrCnt: integer;
begin
  Result := False;
  iErrCnt := 0;
  if LoadImageNames then
  begin
    BuildResMap;

    for I := 0 to Count - 1 do
    begin
      if LoadIcon(i) then
      begin
        MergeIcon(i);
        PrintMsg(format('ok：并入资源（%d）%s', [i, FileNames[i]]));
      end
      else
      begin
        PrintMsg(format('Err: 无法加载 (%d)%s 文件', [i, FileNames[i]]));
        AddLog(format('Err: 无法加载 (%d)%s 文件', [i, FileNames[i]]));
        inc(iErrCnt);
        FSource[i].comment := '空图标';
      end;
    end;

    if iErrCnt > 0 then
      AddLog(format('合并：%d ,%d 个文件无法正常合并', [Count, iErrCnt]));

    BuildIconsID;

    Result := True;
  end
  else
    PrintMsg('Err: ' + MSG_NONAMES);
end;

function TMergeIcons.GetCount: Integer;
begin
  Result := FSourceCount;
end;

function TMergeIcons.GetFileNames(Index: Integer): string;
begin
  Result := FSource[Index].name;
end;

function TMergeIcons.LoadIcon(AIndex: Integer): Boolean;
begin
  try
    Result := False;
    if FileExists(FileNames[AIndex]) then
    begin
      FIcon.LoadFromFile(FileNames[AIndex]);
      Result := not FIcon.Empty;
    end;
  except
    Result := False;
  end;
end;

function TMergeIcons.LoadImageNames: Boolean;
var
  I: Integer;
begin
  // 排序，使生成的多个ID列表相同
  //  如 16x16 列表 和 32x32 列表的索引号是相同的
  FParams.FileList.Sort;
  FSourceCount := 0;
  for I := 0 to FParams.FileList.Count - 1 do
  begin
    SetLength(FSource, FParams.FileList.Count);
    FSource[FSourceCount].name := FParams.FileList[i];
    FSource[FSourceCount].comment := '';
    inc(FSourceCount);
  end;
  Result := FSourceCount > 0;
end;

function TMergeIcons.MergeIcon(AIndex: Integer): Boolean;
var
  iCol: Integer;
  iRow: Integer;
begin
  Result := True;
  iRow := AIndex div FColCnt;
  iCol := AIndex mod FColCnt;

  FIconMap.Canvas.Draw(FWidth * iCol, FHeight * iRow, FIcon);
end;

function TMergeIcons.Save(const AOutFileName: string): Boolean;
begin
  Result := inherited Save(AOutFileName);
  if Result then
    SaveResIconIndexDefine(ChangeFileExt(AOutFileName, '.inc'));
end;

procedure TMergeIcons.SaveResIconIndexDefine(const AFileName: string);
var
  cIDList: TStringList;
  cStr: TStringBuilder;
  I: Integer;
  sPrefix: string;
begin
  if Count = 0 then
    Exit;

  cIDList := TStringList.Create;
  cIDList.Capacity := count + 5;
  cIDList.Add('//');
  cIDList.Add('// 由'+ ExtractFileName(ParamStr(0)) + '程序自动生成，不要手动修改，以免重新生成覆盖自定义内容。');
  cIDlist.add('// create: ' + DateToStr(now));
  cIDList.Add('//');
  cIDList.Add('');

  cStr := TStringBuilder.Create;

  for I := 0 to count - 1 do
  begin
    cStr.Length := 0;
    cStr.Append(FSource[i].ID);

    if cStr.Length < 37 then
      cStr.Append(' ', 37 - cStr.Length);
    cStr.Append('= ');
    cStr.Append(i);
    cStr.Append(';');

    cIDList.Add(cStr.ToString);
  end;
  cStr.Free;


  cIDList.Add('');
  cIDList.Add('// Image names');
  sPrefix := '';
  if assigned(FParams) then
  begin
    if FParams.ResPrefix <> '' then
      sPrefix := FParams.ResPrefix
    else
      sPrefix := ExtractRecName(FParams.OutFileName);
  end;
  cStr := TStringBuilder.Create;
  try


    cStr.AppendFormat('IDI_%sNames: array [0..%d] of string = ( ', [sPrefix, count - 1]);
    for I := 0 to count - 1 do
    begin
      if cStr.Length > 80 then
      begin
        cIDList.Add(cStr.ToString);
        cStr.Clear;
        cStr.Append('        ');
      end;
      cStr.Append(QuotedStr(ExtractRecName(FSource[i].name)) + ',');
    end;
    cStr.Length := cStr.Length - 1;
    cStr.Append(');');
    cIDList.Add(cStr.ToString);
  finally
    cStr.Free;
  end;

  cIDList.SaveToFile(AFileName);
  cIDList.Free;
end;

var
  cSrv: TMergeSrv;

{ TPngPack }

function TPngPack.Exec(PrintMsg: TPrintProc): Boolean;
var
  cSrc: TPngImage;
begin
  Result := False;
  exit;
  cSrc := TPngImage.Create;
  try
    //cSrc.LoadFromFile( SourceFile);
    if not cSrc.Empty then
    begin
      BuildMap(cSrc.Width, cSrc.Height);
      ResMap.Canvas.Draw(0, 0, cSrc);
      Result := True;
    end;
  finally
    cSrc.Free
  end;
end;

{ TConvertRes }

procedure TConvertRes.AddLog(const AMsg: string);
begin
  if Assigned(FOnLogEvent) then
    FOnLogEvent(AMsg);
end;

procedure TConvertRes.BuildMap(w, h:Integer);
begin
  FIconMap := TBitmap.Create;
  FIconMap.PixelFormat := pf32bit;
  FIconMap.alphaFormat := afIgnored;
  FIconMap.SetSize(w, h);
  // Alpha 透明化
  FIconMap.Canvas.Brush.Color := clBlack;
  FIconMap.Canvas.FillRect(Rect(0, 0, FIconMap.Width, FIconMap.Height));
end;

constructor TConvertRes.Create(AFiles: TParams);
begin
  FParams := AFiles;
end;

destructor TConvertRes.Destroy;
begin
  if FIconMap <> nil then
    FIconMap.Free;
  inherited;
end;

function TConvertRes.Save(const AOutFileName: string): Boolean;
var
  cData: TMemoryStream;
  cPack: TZCompressionStream;
  ASource : TBitmap;
begin
  ASource := FIconMap;
  Result := False;
  if ASource = nil then
    Exit;

  if not DirectoryExists(ExtractFilePath(AOutFileName)) then
    if not CreateDir(ExtractFilePath(AOutFileName)) then
      Exit;


  cData := TMemoryStream.Create;
  try
    ASource.SaveToStream(cData);

    cData.SaveToFile(AOutFileName);
    cData.Clear;

    cPack := TZCompressionStream.Create(clMax, cData);
    try
      ASource.SaveToStream(cPack);
    finally
      cPack.free;
    end;
    cData.SaveToFile(ChangeFileExt(AOutFileName, '.IconPack'));

  finally
    cData.Free;
  end;
  Result := True;
end;

begin
{$ifdef debug}
  ReportMemoryLeaksOnShutdown := True;
  {$endif}
  cSrv := TMergeSrv.Create;
  try
    cSrv.Exec;
  finally
    cSrv.Free;
  end;
end.
