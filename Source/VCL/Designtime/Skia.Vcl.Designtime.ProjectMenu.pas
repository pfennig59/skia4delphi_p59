{************************************************************************}
{                                                                        }
{                              Skia4Delphi                               }
{                                                                        }
{ Copyright (c) 2011-2022 Google LLC.                                    }
{ Copyright (c) 2021-2022 Skia4Delphi Project.                           }
{                                                                        }
{ Use of this source code is governed by a BSD-style license that can be }
{ found in the LICENSE file.                                             }
{                                                                        }
{************************************************************************}
unit Skia.Vcl.Designtime.ProjectMenu;

interface

{$SCOPEDENUMS ON}

procedure Register;

implementation

uses
  { Delphi }
  Winapi.Windows,
  Winapi.ShLwApi,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.IOUtils,
  System.TypInfo,
  System.Generics.Collections,
  Vcl.ActnList,
  Vcl.Dialogs,
  ToolsAPI,
  DeploymentAPI,
  DesignIntf,
  DCCStrs;

type
  TSkProjectConfig = (Release, Debug);
  TSkProjectPlatform = (Unknown, Win32, Win64, Android, Android64, iOSDevice32, iOSDevice64, iOSSimulator, OSX64, OSXARM64, Linux64);

  { TSkDeployFile }

  TSkDeployFile = record
    &Platform: TSkProjectPlatform;
    LocalFileName: string;
    RemotePath: string;
    CopyToOutput: Boolean;
    Required: Boolean;
    Operation: TDeployOperation;
    Condition: string;
  end;

  { TSkProjectConfigHelper }

  TSkProjectConfigHelper = record helper for TSkProjectConfig
    function ToString: string;
    class function FromString(const AText: string): TSkProjectConfig; static;
  end;

  { TSkProjectPlatformHelper }

  TSkProjectPlatformHelper = record helper for TSkProjectPlatform
    function ToString: string;
    class function FromString(const AText: string): TSkProjectPlatform; static;
  end;

  { TSkProjectMenuCreatorNotifier }

  TSkProjectMenuCreatorNotifier = class(TNotifierObject, IOTANotifier, IOTAProjectMenuItemCreatorNotifier)
  strict private
    class var FNotifierIndex: Integer;
    class constructor Create;
    class destructor Destroy;
    { IOTAProjectMenuItemCreatorNotifier }
    procedure AddMenu(const AProject: IOTAProject; const AIdentList: TStrings; const AProjectManagerMenuList: IInterfaceList; AIsMultiSelect: Boolean);
  public
    class procedure Register; static;
  end;

  { TSkProjectManagerMenu }

  TSkProjectManagerMenu = class(TNotifierObject, IOTALocalMenu, IOTAProjectManagerMenu)
  strict private
    FCaption: string;
    FExecuteProc: TProc;
    FName: string;
    FParent: string;
    FPosition: Integer;
    FVerb: string;
  strict protected
    { IOTALocalMenu }
    function GetCaption: string;
    function GetChecked: Boolean; virtual;
    function GetEnabled: Boolean; virtual;
    function GetHelpContext: Integer;
    function GetName: string;
    function GetParent: string;
    function GetPosition: Integer;
    function GetVerb: string;
    procedure SetCaption(const AValue: string);
    procedure SetChecked(AValue: Boolean);
    procedure SetEnabled(AValue: Boolean);
    procedure SetHelpContext(AValue: Integer);
    procedure SetName(const AValue: string);
    procedure SetParent(const AValue: string);
    procedure SetPosition(AValue: Integer);
    procedure SetVerb(const AValue: string);
    { IOTAProjectManagerMenu }
    function GetIsMultiSelectable: Boolean;
    procedure Execute(const AMenuContextList: IInterfaceList); overload;
    function PostExecute(const AMenuContextList: IInterfaceList): Boolean;
    function PreExecute(const AMenuContextList: IInterfaceList): Boolean;
    procedure SetIsMultiSelectable(AValue: Boolean);
  public
    constructor Create(const ACaption, AVerb: string; const APosition: Integer; const AExecuteProc: TProc = nil;
      const AName: string = ''; const AParent: string = '');
  end;

  { TSkProjectManagerMenuSeparator }

  TSkProjectManagerMenuSeparator = class(TSkProjectManagerMenu)
  public
    constructor Create(const APosition: Integer); reintroduce;
  end;

  { TSkProjectManagerMenuEnableSkia }

  TSkProjectManagerMenuEnableSkia = class(TSkProjectManagerMenu)
  strict private
    FIsSkiaEnabled: Boolean;
    procedure SetDeployFiles(const AProject: IOTAProject; const AConfig: TSkProjectConfig; const APlatform: TSkProjectPlatform; const AEnabled: Boolean);
    procedure SetSkiaEnabled(const AProject: IOTAProject; const AEnabled: Boolean);
  strict protected
    function GetEnabled: Boolean; override;
  public
    constructor Create(const AProject: IOTAProject; const APosition: Integer); reintroduce;
  end;

  { TSkCompileNotifier }

  TSkCompileNotifier = class(TInterfacedObject, IOTACompileNotifier)
  strict private
    const
      UnsupportedPlatformMessage =
        'The Skia does not support the platform %s in this RAD Studio version.' + sLineBreak + sLineBreak +
        'To avoid problems, disable Skia in this project (Project menu > %s) or, if you want to disable it just in ' +
        'a specific platform, set the define directive "%s" in the project settings of this platform. In both cases, ' +
        'be sure you are not using any Skia units, otherwise you will get "runtime error" on startup of your application.';
    class var FNotifierIndex: Integer;
    class constructor Create;
    class destructor Destroy;
    { IOTACompileNotifier }
    procedure ProjectCompileStarted(const AProject: IOTAProject; AMode: TOTACompileMode);
    procedure ProjectCompileFinished(const AProject: IOTAProject; AResult: TOTACompileResult);
    procedure ProjectGroupCompileStarted(AMode: TOTACompileMode);
    procedure ProjectGroupCompileFinished(AResult: TOTACompileResult);
  public
    class procedure Register; static;
  end;

  { TSkProjectHelper }

  TSkProjectHelper = record
  strict private
    class function ContainsStringInArray(const AString: string; const AArray: TArray<string>): Boolean; static; inline;
    class function GetIsSkiaDefined(const AProject: IOTAProject): Boolean; static;
    class procedure SetIsSkiaDefined(const AProject: IOTAProject; const AValue: Boolean); static;
  public
    class procedure AddDeployFile(const AProject: IOTAProject; const AConfig: TSkProjectConfig; const ADeployFile: TSkDeployFile); static;
    class function IsSkiaDefinedForPlatform(const AProject: IOTAProject; const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig): Boolean; static;
    class procedure RemoveDeployFile(const AProject: IOTAProject; const AConfig: TSkProjectConfig; const APlatform: TSkProjectPlatform; ALocalFileName: string; const ARemoteDir: string); static;
    class procedure RemoveDeployFilesOfClass(const AProject: IOTAProject); overload; static;
    class procedure RemoveDeployFilesOfClass(const AProject: IOTAProject; const AConfig: TSkProjectConfig; const APlatform: TSkProjectPlatform); overload; static;
    class procedure RemoveUnexpectedDeployFilesOfClass(const AProject: IOTAProject; const AConfig: TSkProjectConfig; const APlatform: TSkProjectPlatform; const AAllowedFiles: TArray<TSkDeployFile>); static;
    class function SupportsSkiaDeployment(const AProject: IOTAProject): Boolean; static;
    class property IsSkiaDefined[const AProject: IOTAProject]: Boolean read GetIsSkiaDefined write SetIsSkiaDefined;
  end;

  { TSkOTAHelper }

  TSkOTAHelper = record
  strict private
    const
      DefaultOptionsSeparator = ';';
      OutputDirPropertyName = 'OutputDir';
    class function ExpandConfiguration(const ASource: string; const AConfig: IOTABuildConfiguration): string; static;
    class function ExpandEnvironmentVar(var AValue: string): Boolean; static;
    class function ExpandOutputPath(const ASource: string; const ABuildConfig: IOTABuildConfiguration): string; static;
    class function ExpandPath(const ABaseDir, ARelativeDir: string): string; static;
    class function ExpandVars(const ASource: string): string; static;
    class function GetEnvironmentVars(const AVars: TStrings; AExpand: Boolean): Boolean; static;
    class function GetProjectOptionsConfigurations(const AProject: IOTAProject): IOTAProjectOptionsConfigurations; static;
    class procedure MultiSzToStrings(const ADest: TStrings; const ASource: PChar); static;
    class procedure StrResetLength(var S: string); static;
    class function TryGetProjectOutputPath(const AProject: IOTAProject; ABuildConfig: IOTABuildConfiguration; out AOutputPath: string): Boolean; overload; static;
  public
    class function ContainsOptionValue(const AValues, AValue: string; const ASeparator: string = DefaultOptionsSeparator): Boolean; static;
    class function GetEnvironmentVar(const AName: string; AExpand: Boolean): string; static;
    class function InsertOptionValue(const AValues, AValue: string; const ASeparator: string = DefaultOptionsSeparator): string; static;
    class function RemoveOptionValue(const AValues, AValue: string; const ASeparator: string = DefaultOptionsSeparator): string; static;
    class function TryCopyFileToOutputPath(const AProject: IOTAProject; const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig; const AFileName: string): Boolean; static;
    class function TryCopyFileToOutputPathOfActiveBuild(const AProject: IOTAProject; const AFileName: string): Boolean; static;
    class function TryGetBuildConfig(const AProject: IOTAProject; const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig; out ABuildConfig: IOTABuildConfiguration): Boolean; static;
    class function TryGetProjectOutputPath(const AProject: IOTAProject; const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig; out AOutputPath: string): Boolean; overload; static;
    class function TryGetProjectOutputPathOfActiveBuild(const AProject: IOTAProject; out AOutputPath: string): Boolean; static;
    class function TryRemoveOutputFile(const AProject: IOTAProject; const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig; AFileName: string): Boolean; static;
    class function TryRemoveOutputFileOfActiveBuild(const AProject: IOTAProject; const AFileName: string): Boolean; static;
  end;

  { TSkia4DelphiProject }

  TSkia4DelphiProject = class
  strict private
    const
      DeployFile: array[0..7] of TSkDeployFile = (
        (&Platform: TSkProjectPlatform.Win32;     LocalFileName: 'Binary\Win32\Release\sk4d.dll';       RemotePath: '.\';                       CopyToOutput: True;  Required: True; Operation: TDeployOperation.doCopyOnly;   Condition: ''), // Win32
        (&Platform: TSkProjectPlatform.Win64;     LocalFileName: 'Binary\Win64\Release\sk4d.dll';       RemotePath: '.\';                       CopyToOutput: True;  Required: True; Operation: TDeployOperation.doCopyOnly;   Condition: ''), // Win64
        (&Platform: TSkProjectPlatform.Android;   LocalFileName: 'Binary\Android\Release\libsk4d.so';   RemotePath: 'library\lib\armeabi-v7a\'; CopyToOutput: False; Required: True; Operation: TDeployOperation.doSetExecBit; Condition: ''), // Android
        (&Platform: TSkProjectPlatform.Android64; LocalFileName: 'Binary\Android64\Release\libsk4d.so'; RemotePath: 'library\lib\arm64-v8a\';   CopyToOutput: False; Required: True; Operation: TDeployOperation.doSetExecBit; Condition: ''), // Android64
        (&Platform: TSkProjectPlatform.Android64; LocalFileName: 'Binary\Android\Release\libsk4d.so';   RemotePath: 'library\lib\armeabi-v7a\'; CopyToOutput: False; Required: True; Operation: TDeployOperation.doSetExecBit; Condition: '''$(AndroidAppBundle)''==''true'''), // Android64
        (&Platform: TSkProjectPlatform.OSX64;     LocalFileName: 'Binary\OSX64\Release\sk4d.dylib';     RemotePath: 'Contents\MacOS\';          CopyToOutput: False; Required: True; Operation: TDeployOperation.doSetExecBit; Condition: ''), // OSX64
        (&Platform: TSkProjectPlatform.OSXARM64;  LocalFileName: 'Binary\OSXARM64\Release\sk4d.dylib';  RemotePath: 'Contents\MacOS\';          CopyToOutput: False; Required: True; Operation: TDeployOperation.doSetExecBit; Condition: ''), // OSXARM64
        (&Platform: TSkProjectPlatform.Linux64;   LocalFileName: 'Binary\Linux64\Release\libsk4d.so';   RemotePath: '.\';                       CopyToOutput: False; Required: True; Operation: TDeployOperation.doSetExecBit; Condition: '')  // Linux64
      );
    class var
      FAbsolutePath: string;
      FPath: string;
      FPathChecked: Boolean;
    class procedure FindPath(out APath, AAbsolutePath: string); static;
    class function GetAbsolutePath: string; static;
    class function GetFound: Boolean; static;
    class function GetPath: string; static;
    class function IsValidSkiaDir(const APath: string): Boolean; static;
  public
    const
      DeploymentClass       = 'Skia';
      ProjectDefine         = 'SKIA';
      ProjectDisabledDefine = 'SKIA_DISABLED';
      SkiaDirVariable       = 'SKIADIR';
      MenuCaption: array[Boolean] of string = ('Enable Skia', 'Disable Skia');
      {$IF CompilerVersion < 28} // Below RAD Studio XE7
      SupportedPlatforms = [];
      {$ELSEIF CompilerVersion < 33} // RAD Studio XE7 to RAD Studio 10.2 Tokyo
      SupportedPlatforms = [TSkProjectPlatform.Win32, TSkProjectPlatform.Win64];
      {$ELSEIF CompilerVersion < 35} // RAD Studio 10.3 Rio and RAD Studio 10.4 Sydney
      SupportedPlatforms = [TSkProjectPlatform.Win32, TSkProjectPlatform.Win64, TSkProjectPlatform.Android,
        TSkProjectPlatform.Android64];
      {$ELSE} // RAD Studio 11 Alexandria and newer
      SupportedPlatforms = [TSkProjectPlatform.Win32, TSkProjectPlatform.Win64, TSkProjectPlatform.Android,
        TSkProjectPlatform.Android64, TSkProjectPlatform.iOSDevice64, TSkProjectPlatform.OSX64,
        TSkProjectPlatform.OSXARM64, TSkProjectPlatform.Linux64];
      {$ENDIF}
    class function GetDeployFiles(const APlatform: TSkProjectPlatform): TArray<TSkDeployFile>; static;
    class property AbsolutePath: string read GetAbsolutePath;
    class property Found: Boolean read GetFound;
    class property Path: string read GetPath;
  end;

const
  InvalidNotifier = -1;

{ TSkProjectHelper }

class procedure TSkProjectHelper.AddDeployFile(const AProject: IOTAProject;
  const AConfig: TSkProjectConfig; const ADeployFile: TSkDeployFile);
type
  TDeployFileExistence = (DoesNotExist, AlreadyExists, NeedReplaced);

  function GetDeployFileExistence(const AProjectDeployment: IProjectDeployment;
    const ALocalFileName, ARemoteDir, APlatformName, AConfigName: string): TDeployFileExistence;
  var
    LRemoteFileName: string;
    LFile: IProjectDeploymentFile;
    LFiles: TDictionary<string, IProjectDeploymentFile>.TValueCollection;
  begin
    Result := TDeployFileExistence.DoesNotExist;
    LRemoteFileName := TPath.Combine(ARemoteDir, TPath.GetFileName(ALocalFileName));
    LFiles := AProjectDeployment.Files;
    if Assigned(LFiles) then
    begin
      for LFile in LFiles do
      begin
        if (LFile.FilePlatform = APlatformName) and (LFile.Configuration = AConfigName) then
        begin
          if SameText(LRemoteFileName, TPath.Combine(LFile.RemoteDir[APlatformName], LFile.RemoteName[APlatformName])) then
          begin
            if (LFile.LocalName = ALocalFileName) and (LFile.DeploymentClass = TSkia4DelphiProject.DeploymentClass) and
              (LFile.Condition = ADeployFile.Condition) and (LFile.Operation[APlatformName] = ADeployFile.Operation) and
              LFile.Enabled[APlatformName] and LFile.Overwrite[APlatformName] and
              (LFile.Required = ADeployFile.Required) and (Result = TDeployFileExistence.DoesNotExist) then
            begin
              Result := TDeployFileExistence.AlreadyExists;
            end
            else
              Exit(TDeployFileExistence.NeedReplaced);
          end;
        end;
      end;
    end;
  end;

  procedure DoAddDeployFile(const AProjectDeployment: IProjectDeployment;
    const ALocalFileName, APlatformName, AConfigName: string);
  var
    LFile: IProjectDeploymentFile;
  begin
    LFile := AProjectDeployment.CreateFile(AConfigName, APlatformName, ALocalFileName);
    if Assigned(LFile) then
    begin
      LFile.Overwrite[APlatformName] := True;
      LFile.Enabled[APlatformName] := True;
      LFile.Required := ADeployFile.Required;
      LFile.Condition := ADeployFile.Condition;
      LFile.Operation[APlatformName] := ADeployFile.Operation;
      LFile.RemoteDir[APlatformName] := ADeployFile.RemotePath;
      LFile.DeploymentClass := TSkia4DelphiProject.DeploymentClass;
      LFile.RemoteName[APlatformName] := TPath.GetFileName(ALocalFileName);
      AProjectDeployment.AddFile(AConfigName, APlatformName, LFile);
    end;
  end;

var
  LProjectDeployment: IProjectDeployment;
  LConfigName: string;
  LPlatformName: string;
  LLocalFileName: string;
  LDeployFileExistence: TDeployFileExistence;
begin
  if (ADeployFile.LocalFileName <> '') and Supports(AProject, IProjectDeployment, LProjectDeployment)  then
  begin
    LConfigName := AConfig.ToString;
    LPlatformName := ADeployFile.Platform.ToString;
    LLocalFileName := TPath.Combine(TSkia4DelphiProject.Path, ADeployFile.LocalFileName);
    LDeployFileExistence := GetDeployFileExistence(LProjectDeployment, LLocalFileName, ADeployFile.RemotePath, LPlatformName, LConfigName);
    if LDeployFileExistence = TDeployFileExistence.NeedReplaced then
      RemoveDeployFile(AProject, AConfig, ADeployFile.Platform, ADeployFile.LocalFileName, ADeployFile.RemotePath);
    if LDeployFileExistence in [TDeployFileExistence.NeedReplaced, TDeployFileExistence.DoesNotExist] then
      DoAddDeployFile(LProjectDeployment, LLocalFileName, LPlatformName, LConfigName);
  end;
end;

class function TSkProjectHelper.ContainsStringInArray(const AString: string;
  const AArray: TArray<string>): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := Low(AArray) to High(AArray) do
    if AArray[I] = AString then
      Exit(True);
end;

class function TSkProjectHelper.GetIsSkiaDefined(
  const AProject: IOTAProject): Boolean;
var
  LBaseConfiguration: IOTABuildConfiguration;
  LOptionsConfigurations: IOTAProjectOptionsConfigurations;
begin
  Result := Assigned(AProject) and Supports(AProject.ProjectOptions, IOTAProjectOptionsConfigurations, LOptionsConfigurations);
  if Result then
  begin
    LBaseConfiguration := LOptionsConfigurations.BaseConfiguration;
    Result := Assigned(LBaseConfiguration) and
      TSkOTAHelper.ContainsOptionValue(LBaseConfiguration.Value[sDefine], TSkia4DelphiProject.ProjectDefine);
  end;
end;

class function TSkProjectHelper.IsSkiaDefinedForPlatform(
  const AProject: IOTAProject; const APlatform: TSkProjectPlatform;
  const AConfig: TSkProjectConfig): Boolean;
var
  LBuildConfig: IOTABuildConfiguration;
begin
  Assert(IsSkiaDefined[AProject]);
  Result := TSkOTAHelper.TryGetBuildConfig(AProject, APlatform, AConfig, LBuildConfig) and
    not TSkOTAHelper.ContainsOptionValue(LBuildConfig.Value[sDefine], TSkia4DelphiProject.ProjectDisabledDefine);
end;

class procedure TSkProjectHelper.RemoveDeployFile(const AProject: IOTAProject;
  const AConfig: TSkProjectConfig; const APlatform: TSkProjectPlatform;
  ALocalFileName: string; const ARemoteDir: string);
var
  LProjectDeployment: IProjectDeployment;
  LFiles: TDictionary<string, IProjectDeploymentFile>.TValueCollection;
  LFile: IProjectDeploymentFile;
  LRemoteFileName: string;
  LRemoveFiles: TArray<IProjectDeploymentFile>;
begin
  if (ALocalFileName <> '') and Supports(AProject, IProjectDeployment, LProjectDeployment) then
  begin
    ALocalFileName := TPath.Combine(TSkia4DelphiProject.Path, ALocalFileName);
    LProjectDeployment.RemoveFile(AConfig.ToString, APlatform.ToString, ALocalFileName);
    LFiles := LProjectDeployment.Files;
    if Assigned(LFiles) then
    begin
      LRemoteFileName := TPath.Combine(ARemoteDir, TPath.GetFileName(ALocalFileName));
      LRemoveFiles := [];
      for LFile in LFiles do
        if SameText(LRemoteFileName, TPath.Combine(LFile.RemoteDir[APlatform.ToString], LFile.RemoteName[APlatform.ToString])) then
          LRemoveFiles := LRemoveFiles + [LFile];
      for LFile in LRemoveFiles do
        LProjectDeployment.RemoveFile(AConfig.ToString, APlatform.ToString, LFile.LocalName);
    end;
  end;
end;

class procedure TSkProjectHelper.RemoveDeployFilesOfClass(
  const AProject: IOTAProject);
var
  LProjectDeployment: IProjectDeployment;
begin
  if Supports(AProject, IProjectDeployment, LProjectDeployment) then
    LProjectDeployment.RemoveFilesOfClass(TSkia4DelphiProject.DeploymentClass);
end;

class procedure TSkProjectHelper.RemoveDeployFilesOfClass(
  const AProject: IOTAProject; const AConfig: TSkProjectConfig;
  const APlatform: TSkProjectPlatform);
var
  LProjectDeployment: IProjectDeployment;
  LFile: IProjectDeploymentFile;
  LConfigName: string;
  LPlatformName: string;
begin
  if Supports(AProject, IProjectDeployment, LProjectDeployment) then
  begin
    LConfigName := AConfig.ToString;
    LPlatformName := APlatform.ToString;
    for LFile in LProjectDeployment.GetFilesOfClass(TSkia4DelphiProject.DeploymentClass) do
      if (LFile.Configuration = LConfigName) and ContainsStringInArray(LPlatformName, LFile.Platforms) then
        LProjectDeployment.RemoveFile(LConfigName, LPlatformName, LFile.LocalName);
  end;
end;

class procedure TSkProjectHelper.RemoveUnexpectedDeployFilesOfClass(
  const AProject: IOTAProject; const AConfig: TSkProjectConfig;
  const APlatform: TSkProjectPlatform; const AAllowedFiles: TArray<TSkDeployFile>);

  function IsAllowedFile(const AFile: IProjectDeploymentFile; const APlatformName: string): Boolean;
  var
    LDeployFile: TSkDeployFile;
  begin
    Result := False;
    for LDeployFile in AAllowedFiles do
    begin
      if (AFile.LocalName = LDeployFile.LocalFileName) and SameText(AFile.RemoteDir[APlatformName], LDeployFile.RemotePath) and
        SameText(AFile.RemoteName[APlatformName], TPath.GetFileName(LDeployFile.LocalFileName)) and
        (AFile.DeploymentClass = TSkia4DelphiProject.DeploymentClass) and
        (AFile.Condition = LDeployFile.Condition) and (AFile.Operation[APlatformName] = LDeployFile.Operation) and
        AFile.Enabled[APlatformName] and AFile.Overwrite[APlatformName] and
        (AFile.Required = LDeployFile.Required) then
      begin
        Exit(True);
      end;
    end;
  end;

var
  LProjectDeployment: IProjectDeployment;
  LFile: IProjectDeploymentFile;
  LConfigName: string;
  LPlatformName: string;
begin
  if Supports(AProject, IProjectDeployment, LProjectDeployment) then
  begin
    LConfigName := AConfig.ToString;
    LPlatformName := APlatform.ToString;
    for LFile in LProjectDeployment.GetFilesOfClass(TSkia4DelphiProject.DeploymentClass) do
    begin
      if (LFile.Configuration = LConfigName) and ContainsStringInArray(LPlatformName, LFile.Platforms) and
        not IsAllowedFile(LFile, LPlatformName) then
      begin
        LProjectDeployment.RemoveFile(LConfigName, LPlatformName, LFile.LocalName);
      end;
    end;
  end;
end;

class procedure TSkProjectHelper.SetIsSkiaDefined(const AProject: IOTAProject;
  const AValue: Boolean);
var
  LProjectOptions: IOTAProjectOptions;
  LOptionsConfigurations: IOTAProjectOptionsConfigurations;
  LBaseConfiguration: IOTABuildConfiguration;
begin
  if Assigned(AProject) then
  begin
    LProjectOptions := AProject.ProjectOptions;
    if Assigned(LProjectOptions) then
    begin
      if Supports(LProjectOptions, IOTAProjectOptionsConfigurations, LOptionsConfigurations) then
      begin
        LBaseConfiguration := LOptionsConfigurations.BaseConfiguration;
        if Assigned(LBaseConfiguration) then
        begin
          if AValue then
            LBaseConfiguration.Value[sDefine] := TSkOTAHelper.InsertOptionValue(LBaseConfiguration.Value[sDefine], TSkia4DelphiProject.ProjectDefine)
          else
            LBaseConfiguration.Value[sDefine] := TSkOTAHelper.RemoveOptionValue(LBaseConfiguration.Value[sDefine], TSkia4DelphiProject.ProjectDefine);
        end;
      end;
      LProjectOptions.ModifiedState := True;
    end;
  end;
end;

class function TSkProjectHelper.SupportsSkiaDeployment(
  const AProject: IOTAProject): Boolean;
begin
  Result := Assigned(AProject) and AProject.FileName.EndsWith('.dproj', True) and
    ((AProject.ApplicationType = sApplication) or (AProject.ApplicationType = sConsole));
end;

{ TSkProjectConfigHelper }

function TSkProjectConfigHelper.ToString: string;
begin
  Result := GetEnumName(TypeInfo(TSkProjectConfig), Ord(Self));
end;

class function TSkProjectConfigHelper.FromString(const AText: string): TSkProjectConfig;
begin
  Result := TSkProjectConfig(GetEnumValue(TypeInfo(TSkProjectConfig), AText));
end;

{ TSkProjectPlatformHelper }

function TSkProjectPlatformHelper.ToString: string;
begin
  Result := GetEnumName(TypeInfo(TSkProjectPlatform), Ord(Self));
end;

class function TSkProjectPlatformHelper.FromString(const AText: string): TSkProjectPlatform;
var
  LEnumValue: Integer;
begin
  LEnumValue := GetEnumValue(TypeInfo(TSkProjectPlatform), AText);
  if LEnumValue = -1 then
    Result := TSkProjectPlatform.Unknown
  else
    Result := TSkProjectPlatform(GetEnumValue(TypeInfo(TSkProjectPlatform), AText));
end;

{ TSkProjectMenuCreatorNotifier }

procedure TSkProjectMenuCreatorNotifier.AddMenu(const AProject: IOTAProject;
  const AIdentList: TStrings; const AProjectManagerMenuList: IInterfaceList;
  AIsMultiSelect: Boolean);
begin
  if (not AIsMultiSelect) and (AIdentList.IndexOf(sProjectContainer) <> -1) and
    Assigned(AProjectManagerMenuList) and TSkProjectHelper.SupportsSkiaDeployment(AProject) then
  begin
    AProjectManagerMenuList.Add(TSkProjectManagerMenuSeparator.Create(pmmpRunNoDebug + 10));
    AProjectManagerMenuList.Add(TSkProjectManagerMenuEnableSkia.Create(AProject, pmmpRunNoDebug + 20));
  end;
end;

class constructor TSkProjectMenuCreatorNotifier.Create;
begin
  FNotifierIndex := InvalidNotifier;
end;

class destructor TSkProjectMenuCreatorNotifier.Destroy;
var
  LProjectManager: IOTAProjectManager;
begin
  if (FNotifierIndex > InvalidNotifier) and Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
    LProjectManager.RemoveMenuItemCreatorNotifier(FNotifierIndex);
end;

class procedure TSkProjectMenuCreatorNotifier.Register;
var
  LProjectManager: IOTAProjectManager;
begin
  if (FNotifierIndex <= InvalidNotifier) and Supports(BorlandIDEServices, IOTAProjectManager, LProjectManager) then
    FNotifierIndex := LProjectManager.AddMenuItemCreatorNotifier(TSkProjectMenuCreatorNotifier.Create);;
end;

{ TSkProjectManagerMenu }

constructor TSkProjectManagerMenu.Create(const ACaption, AVerb: string;
  const APosition: Integer; const AExecuteProc: TProc = nil;
  const AName: string = ''; const AParent: string = '');
begin
  inherited Create;
  FCaption := ACaption;
  FName := AName;
  FParent := AParent;
  FPosition := APosition;
  FVerb := AVerb;
  FExecuteProc := AExecuteProc;
end;

procedure TSkProjectManagerMenu.Execute(const AMenuContextList: IInterfaceList);
begin
  if Assigned(FExecuteProc) then
    FExecuteProc;
end;

function TSkProjectManagerMenu.GetCaption: string;
begin
  Result := FCaption;
end;

function TSkProjectManagerMenu.GetChecked: Boolean;
begin
  Result := False;
end;

function TSkProjectManagerMenu.GetEnabled: Boolean;
begin
  Result := True; // for Show IPA, check platform etc
end;

function TSkProjectManagerMenu.GetHelpContext: Integer;
begin
  Result := 0;
end;

function TSkProjectManagerMenu.GetIsMultiSelectable: Boolean;
begin
  Result := False;
end;

function TSkProjectManagerMenu.GetName: string;
begin
  Result := FName;
end;

function TSkProjectManagerMenu.GetParent: string;
begin
  Result := FParent;
end;

function TSkProjectManagerMenu.GetPosition: Integer;
begin
  Result := FPosition;
end;

function TSkProjectManagerMenu.GetVerb: string;
begin
  Result := FVerb;
end;

function TSkProjectManagerMenu.PostExecute(const AMenuContextList: IInterfaceList): Boolean;
begin
  Result := False;
end;

function TSkProjectManagerMenu.PreExecute(const AMenuContextList: IInterfaceList): Boolean;
begin
  Result := False;
end;

procedure TSkProjectManagerMenu.SetCaption(const AValue: string);
begin
end;

procedure TSkProjectManagerMenu.SetChecked(AValue: Boolean);
begin
end;

procedure TSkProjectManagerMenu.SetEnabled(AValue: Boolean);
begin
end;

procedure TSkProjectManagerMenu.SetHelpContext(AValue: Integer);
begin
end;

procedure TSkProjectManagerMenu.SetIsMultiSelectable(AValue: Boolean);
begin
end;

procedure TSkProjectManagerMenu.SetName(const AValue: string);
begin
end;

procedure TSkProjectManagerMenu.SetParent(const AValue: string);
begin
end;

procedure TSkProjectManagerMenu.SetPosition(AValue: Integer);
begin
end;

procedure TSkProjectManagerMenu.SetVerb(const AValue: string);
begin
end;

{ TSkProjectManagerMenuSeparator }

constructor TSkProjectManagerMenuSeparator.Create(const APosition: Integer);
begin
  inherited Create('-', '', APosition);
end;

{ TSkProjectManagerMenuEnableSkia }

constructor TSkProjectManagerMenuEnableSkia.Create(const AProject: IOTAProject;
  const APosition: Integer);
begin
  FIsSkiaEnabled := TSkProjectHelper.IsSkiaDefined[AProject];
  inherited Create(TSkia4DelphiProject.MenuCaption[FIsSkiaEnabled], '', APosition,
    procedure()
    begin
      SetSkiaEnabled(AProject, not FIsSkiaEnabled);
    end);
end;

function TSkProjectManagerMenuEnableSkia.GetEnabled: Boolean;
begin
  Result := FIsSkiaEnabled or TSkia4DelphiProject.Found;
end;

procedure TSkProjectManagerMenuEnableSkia.SetDeployFiles(
  const AProject: IOTAProject; const AConfig: TSkProjectConfig;
  const APlatform: TSkProjectPlatform; const AEnabled: Boolean);
var
  LDeployFile: TSkDeployFile;
begin
  if TSkProjectHelper.SupportsSkiaDeployment(AProject) then
  begin
    if AEnabled and (APlatform in TSkia4DelphiProject.SupportedPlatforms) then
    begin
      for LDeployFile in TSkia4DelphiProject.GetDeployFiles(APlatform) do
        TSkProjectHelper.AddDeployFile(AProject, AConfig, LDeployFile);
    end
    else
    begin
      for LDeployFile in TSkia4DelphiProject.GetDeployFiles(APlatform) do
      begin
        TSkProjectHelper.RemoveDeployFile(AProject, AConfig, APlatform, LDeployFile.LocalFileName, LDeployFile.RemotePath);
        if LDeployFile.CopyToOutput then
          TSkOTAHelper.TryRemoveOutputFile(AProject, APlatform, AConfig, TPath.GetFileName(LDeployFile.LocalFileName));
      end;
    end;
  end;
end;

procedure TSkProjectManagerMenuEnableSkia.SetSkiaEnabled(
  const AProject: IOTAProject; const AEnabled: Boolean);

  function SupportsPlatform(const APlatform: TSkProjectPlatform): Boolean;
  var
    LPlatformName: string;
    LSupportedPlatform: string;
  begin
    if APlatform <> TSkProjectPlatform.Unknown then
    begin
      LPlatformName := APlatform.ToString;
      for LSupportedPlatform in AProject.SupportedPlatforms do
        if SameText(LPlatformName, LSupportedPlatform) then
          Exit(True);
    end;
    Result := False;
  end;

  function ApplyDelphiSourceChange(var ASource: string; const AEnabled: Boolean): Boolean;

    // Add the "Skia.FMX" to uses, after the FMX.Forms, if it isn't inside a ifdef
    function AddSkiaFMXUnit(const ASourceList: TStringList): Boolean;
    var
      LIfDefCount: Integer;
      I: Integer;
    begin
      Result := False;
      for I := 0 to ASourceList.Count - 1 do
        if ASourceList[I].TrimLeft.StartsWith('Skia.FMX,', True) or ASourceList[I].TrimLeft.StartsWith('Skia.FMX ', True) then
          Exit;
      LIfDefCount := 0;
      for I := 0 to ASourceList.Count - 1 do
      begin
        if ASourceList[I].TrimLeft.StartsWith('{$IF', True) then
          Inc(LIfDefCount);
        if ASourceList[I].ToUpper.Contains('{$END') then
          LIfDefCount := Max(LIfDefCount - 1, 0);
        if ASourceList[I].TrimLeft.StartsWith('FMX.Forms,', True) or ASourceList[I].TrimLeft.StartsWith('FMX.Forms ', True) then
        begin
          if LIfDefCount = 0 then
          begin
            ASourceList.Insert(I + 1, '  Skia.FMX,');
            Exit(True);
          end
          else
            Break;
        end;
      end;
    end;

    function AddGlobalUseSkia(const ASourceList: TStringList): Boolean;
    var
      LIfDefCount: Integer;
      I: Integer;
    begin
      Result := False;
      if not ASourceList.Text.ToLower.Contains(string('Skia.FMX,').ToLower) and
        not ASourceList.Text.ToLower.Contains(string('Skia.FMX ').ToLower) then
      begin
        Exit;
      end;
      for I := 0 to ASourceList.Count - 1 do
        if ASourceList[I].Replace(' ', '').StartsWith('GlobalUseSkia:=True', True) then
          Exit;
      LIfDefCount := 0;
      for I := ASourceList.Count - 1 downto 0 do
      begin
        if ASourceList[I].ToUpper.Contains('{$END') then
          Inc(LIfDefCount);
        if ASourceList[I].TrimLeft.StartsWith('{$IF', True) then
          LIfDefCount := Max(LIfDefCount - 1, 0);
        if SameText(ASourceList[I].Replace(' ', ''), 'GlobalUseSkia:=False;') and (LIfDefCount = 0) then
          ASourceList.Delete(I);
      end;
      for I := 0 to ASourceList.Count - 1 do
      begin
        if SameText(ASourceList[I].Trim, 'begin') then
        begin
          ASourceList.Insert(I + 1, '  GlobalUseSkia := True;');
          Exit(True);
        end;
      end;
    end;

    // Remove line starting with specific text, if it isn't inside a ifdef
    function RemoveLineStartingWith(const ASourceList: TStringList; AStartText: string): Boolean;
    var
      LIfDefCount: Integer;
      I: Integer;
    begin
      Result := False;
      AStartText := AStartText.Replace(' ', '');
      LIfDefCount := 0;
      for I := ASourceList.Count - 1 downto 0 do
      begin
        if ASourceList[I].ToUpper.Contains('{$END') then
          Inc(LIfDefCount);
        if ASourceList[I].TrimLeft.StartsWith('{$IF', True) then
          LIfDefCount := Max(LIfDefCount - 1, 0);
        if ASourceList[I].Replace(' ', '').StartsWith(AStartText) then
        begin
          if LIfDefCount = 0 then
          begin
            ASourceList.Delete(I);
            Result := True;
          end
          else
            Break;
        end;
      end;
    end;

  var
    LSourceList: TStringList;
  begin
    LSourceList := TStringList.Create;
    try
      {$IF CompilerVersion >= 31}
      LSourceList.TrailingLineBreak := False;
      {$ENDIF}
      LSourceList.Text := ASource;
      if AEnabled then
      begin
        Result := AddSkiaFMXUnit(LSourceList);
        Result := AddGlobalUseSkia(LSourceList) or Result;
      end
      else
      begin
        Result := RemoveLineStartingWith(LSourceList, '  Skia.FMX,');
        Result := RemoveLineStartingWith(LSourceList, '  GlobalUseSkia :=') or Result;
        Result := RemoveLineStartingWith(LSourceList, '  GlobalUseSkiaRasterWhenAvailable :=') or Result;
      end;
      if Result then
      begin
        ASource := LSourceList.Text;
        {$IF CompilerVersion < 31}
        ASource := ASource.TrimRight;
        {$ENDIF}
      end;
    finally
      LSourceList.Free;
    end;
  end;

  function GetEditorString(const ASourceEditor: IOTASourceEditor70; out AValue: string): Boolean;
  const
    BufferSize: Integer = 1024;
  var
    LReader: IOTAEditReader;
    LReadCount: Integer;
    LPosition: Integer;
    LBuffer: AnsiString;
  begin
    LReader := ASourceEditor.CreateReader;
    Result := Assigned(LReader);
    if Result then
    begin
      AValue := '';
      LPosition := 0;
      repeat
        SetLength(LBuffer, BufferSize);
        LReadCount := LReader.GetText(LPosition, PAnsiChar(LBuffer), BufferSize);
        SetLength(LBuffer, LReadCount);
        AValue := AValue + string(LBuffer);
        Inc(LPosition, LReadCount);
      until LReadCount < BufferSize;
    end;
  end;

  procedure SetEditorString(const ASourceEditor: IOTASourceEditor70; const AValue: string);
  var
    LEditorWriter: IOTAEditWriter;
  begin
    LEditorWriter := ASourceEditor.CreateUndoableWriter;
    if Assigned(LEditorWriter) then
    begin
      LEditorWriter.CopyTo(0);
      LEditorWriter.DeleteTo(MaxInt);
      LEditorWriter.Insert(PAnsiChar(AnsiString(AValue)));
      ASourceEditor.MarkModified;
    end;
  end;

  procedure ChangeSource(const AProject: IOTAProject; const AEnabled: Boolean);
  var
    LSourceEditor: IOTASourceEditor70;
    LSourceText: string;
    I: Integer;
  begin
    if AProject.FrameworkType = sFrameworkTypeFMX then
    begin
      for I := 0 to AProject.GetModuleFileCount - 1 do
      begin
        if Supports(AProject.ModuleFileEditors[I], IOTASourceEditor70, LSourceEditor) and
          GetEditorString(LSourceEditor, LSourceText) then
        begin
          if (AProject.Personality = sDelphiPersonality) and ApplyDelphiSourceChange(LSourceText, AEnabled) then
            SetEditorString(LSourceEditor, LSourceText);
        end;
      end;
    end;
  end;

var
  LPlatform: TSkProjectPlatform;
  LConfig: TSkProjectConfig;
  LProjectOptions: IOTAProjectOptions;
begin
  for LPlatform := Low(TSkProjectPlatform) to High(TSkProjectPlatform) do
    if SupportsPlatform(LPlatform) then
      for LConfig := Low(TSkProjectConfig) to High(TSkProjectConfig) do
        SetDeployFiles(AProject, LConfig, LPlatform, AEnabled);
  // Remove remaing files from old versions
  if not AEnabled then
    TSkProjectHelper.RemoveDeployFilesOfClass(AProject);

  TSkProjectHelper.IsSkiaDefined[AProject] := AEnabled;
  LProjectOptions := AProject.ProjectOptions;
  if Assigned(LProjectOptions) then
    LProjectOptions.ModifiedState := True;
  ChangeSource(AProject, AEnabled);

  {$IF CompilerVersion >= 35}
  var LProjectBuilder := AProject.ProjectBuilder;
  if Assigned(LProjectBuilder) then
    LProjectBuilder.BuildProject(TOTACompileMode.cmOTAClean, False, True);
  {$ENDIF}
end;

{ TSkCompileNotifier }

class constructor TSkCompileNotifier.Create;
begin
  FNotifierIndex := InvalidNotifier;
end;

class destructor TSkCompileNotifier.Destroy;
var
  LCompileServices: IOTACompileServices;
begin
  if (FNotifierIndex > InvalidNotifier) and Supports(BorlandIDEServices, IOTACompileServices, LCompileServices) then
    LCompileServices.RemoveNotifier(FNotifierIndex);
end;

procedure TSkCompileNotifier.ProjectCompileFinished(const AProject: IOTAProject;
  AResult: TOTACompileResult);
begin
end;

procedure TSkCompileNotifier.ProjectCompileStarted(const AProject: IOTAProject;
  AMode: TOTACompileMode);
var
  LPlatform: TSkProjectPlatform;
  LConfig: TSkProjectConfig;
  LDeployFile: TSkDeployFile;
begin
  if TSkProjectHelper.SupportsSkiaDeployment(AProject) then
  begin
    if Assigned(AProject) then
      LPlatform := TSkProjectPlatform.FromString(AProject.CurrentPlatform)
    else
      LPlatform := TSkProjectPlatform.Unknown;
    if LPlatform = TSkProjectPlatform.Unknown then
      Exit;

    if (AMode in [TOTACompileMode.cmOTAMake, TOTACompileMode.cmOTABuild]) and
      TSkProjectHelper.IsSkiaDefined[AProject] and TSkia4DelphiProject.Found then
    begin
      LConfig := TSkProjectConfig.FromString(AProject.CurrentConfiguration);
      if TSkProjectHelper.IsSkiaDefinedForPlatform(AProject, LPlatform, LConfig) then
      begin
        if LPlatform in TSkia4DelphiProject.SupportedPlatforms then
        begin
          TSkProjectHelper.RemoveUnexpectedDeployFilesOfClass(AProject, LConfig, LPlatform, TSkia4DelphiProject.GetDeployFiles(LPlatform));
          for LDeployFile in TSkia4DelphiProject.GetDeployFiles(LPlatform) do
          begin
            if LDeployFile.CopyToOutput then
            begin
              Assert(LDeployFile.LocalFileName <> '');
              TSkOTAHelper.TryCopyFileToOutputPathOfActiveBuild(AProject, TPath.Combine(TSkia4DelphiProject.AbsolutePath, LDeployFile.LocalFileName));
            end;
            TSkProjectHelper.AddDeployFile(AProject, LConfig, LDeployFile);
          end;
        end
        else
        begin
          for LDeployFile in TSkia4DelphiProject.GetDeployFiles(LPlatform) do
            TSkProjectHelper.RemoveDeployFile(AProject, LConfig, LPlatform, LDeployFile.LocalFileName, LDeployFile.RemotePath);
          TSkProjectHelper.RemoveDeployFilesOfClass(AProject, LConfig, LPlatform);
          Showmessage(Format(UnsupportedPlatformMessage, [AProject.CurrentPlatform, TSkia4DelphiProject.MenuCaption[True],
            TSkia4DelphiProject.ProjectDisabledDefine]));
        end;
      end
      else
      begin
        for LDeployFile in TSkia4DelphiProject.GetDeployFiles(LPlatform) do
          TSkProjectHelper.RemoveDeployFile(AProject, LConfig, LPlatform, LDeployFile.LocalFileName, LDeployFile.RemotePath);
        TSkProjectHelper.RemoveDeployFilesOfClass(AProject, LConfig, LPlatform);
      end;
    end
    {$IF CompilerVersion >= 35}
    else if (AMode = TOTACompileMode.cmOTAClean) and TSkProjectHelper.IsSkiaDefined[AProject] then
    begin
      for LDeployFile in TSkia4DelphiProject.GetDeployFiles(LPlatform) do
        if LDeployFile.CopyToOutput then
          TSkOTAHelper.TryRemoveOutputFileOfActiveBuild(AProject, TPath.GetFileName(LDeployFile.LocalFileName));
    end;
    {$ENDIF}
  end;
end;

procedure TSkCompileNotifier.ProjectGroupCompileFinished(
  AResult: TOTACompileResult);
begin
end;

procedure TSkCompileNotifier.ProjectGroupCompileStarted(AMode: TOTACompileMode);
begin
end;

class procedure TSkCompileNotifier.Register;
var
  LCompileServices: IOTACompileServices;
begin
  if (FNotifierIndex <= InvalidNotifier) and Supports(BorlandIDEServices, IOTACompileServices, LCompileServices) then
    FNotifierIndex := LCompileServices.AddNotifier(TSkCompileNotifier.Create);
end;

{ TSkOTAHelper }

class function TSkOTAHelper.ContainsOptionValue(const AValues, AValue,
  ASeparator: string): Boolean;
var
  LValues: TArray<string>;
  I: Integer;
begin
  LValues := AValues.Split([ASeparator], TStringSplitOptions.None);
  for I := 0 to Length(LValues) - 1 do
    if SameText(LValues[I], AValue) then
      Exit(True);
  Result := False;
end;

class function TSkOTAHelper.ExpandConfiguration(const ASource: string;
  const AConfig: IOTABuildConfiguration): string;
begin
  Result := StringReplace(ASource, '$(Platform)', AConfig.Platform, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '$(Config)', AConfig.Name, [rfReplaceAll, rfIgnoreCase]);
end;

class function TSkOTAHelper.ExpandEnvironmentVar(var AValue: string): Boolean;
var
  R: Integer;
  LExpanded: string;
begin
  SetLength(LExpanded, 1);
  R := ExpandEnvironmentStrings(PChar(AValue), PChar(LExpanded), 0);
  SetLength(LExpanded, R);
  Result := ExpandEnvironmentStrings(PChar(AValue), PChar(LExpanded), R) <> 0;
  if Result then
  begin
    StrResetLength(LExpanded);
    AValue := LExpanded;
  end;
end;

class function TSkOTAHelper.ExpandOutputPath(const ASource: string;
  const ABuildConfig: IOTABuildConfiguration): string;
begin
  if Assigned(ABuildConfig) then
    Result := ExpandConfiguration(ASource, ABuildConfig)
  else
    Result := ASource;
  Result := ExpandVars(Result);
end;

class function TSkOTAHelper.ExpandPath(const ABaseDir,
  ARelativeDir: string): string;
var
  LBuffer: array [0..MAX_PATH - 1] of Char;
begin
  if PathIsRelative(PChar(ARelativeDir)) then
    Result := IncludeTrailingPathDelimiter(ABaseDir) + ARelativeDir
  else
    Result := ARelativeDir;
  if PathCanonicalize(@LBuffer[0], PChar(Result)) then
    Result := LBuffer;
end;

class function TSkOTAHelper.ExpandVars(const ASource: string): string;
var
  LVars: TStrings;
  I: Integer;
begin
  Result := ASource;
  if not Result.IsEmpty then
  begin
    LVars := TStringList.Create;
    try
      GetEnvironmentVars(LVars, True);
      for I := 0 to LVars.Count - 1 do
      begin
        Result := StringReplace(Result, '$(' + LVars.Names[I] + ')', LVars.Values[LVars.Names[I]], [rfReplaceAll, rfIgnoreCase]);
        Result := StringReplace(Result, '%' + LVars.Names[I] + '%', LVars.Values[LVars.Names[I]], [rfReplaceAll, rfIgnoreCase]);
      end;
    finally
      LVars.Free;
    end;
  end;
end;

class function TSkOTAHelper.GetEnvironmentVar(const AName: string; AExpand: Boolean): string;
const
  BufSize = 1024;
var
  Len: Integer;
  Buffer: array[0..BufSize - 1] of Char;
  LExpanded: string;
begin
  Result := '';
  Len := Winapi.Windows.GetEnvironmentVariable(PChar(AName), @Buffer, BufSize);
  if Len < BufSize then
    SetString(Result, PChar(@Buffer), Len)
  else
  begin
    SetLength(Result, Len - 1);
    Winapi.Windows.GetEnvironmentVariable(PChar(AName), PChar(Result), Len);
  end;
  if AExpand then
  begin
    LExpanded := Result;
    if ExpandEnvironmentVar(LExpanded) then
      Result := LExpanded;
  end;
end;

class function TSkOTAHelper.GetEnvironmentVars(const AVars: TStrings;
  AExpand: Boolean): Boolean;
var
  LRaw: PChar;
  LExpanded: string;
  I: Integer;
begin
  AVars.BeginUpdate;
  try
    AVars.Clear;
    LRaw := GetEnvironmentStrings;
    try
      MultiSzToStrings(AVars, LRaw);
      Result := True;
    finally
      FreeEnvironmentStrings(LRaw);
    end;
    if AExpand then
    begin
      for I := 0 to AVars.Count - 1 do
      begin
        LExpanded := AVars[I];
        if ExpandEnvironmentVar(LExpanded) then
          AVars[I] := LExpanded;
      end;
    end;
  finally
    AVars.EndUpdate;
  end;
end;

class function TSkOTAHelper.GetProjectOptionsConfigurations(
  const AProject: IOTAProject): IOTAProjectOptionsConfigurations;
var
  LProjectOptions: IOTAProjectOptions;
begin
  Result := nil;
  if AProject <> nil then
  begin
    LProjectOptions := AProject.ProjectOptions;
    if LProjectOptions <> nil then
      Supports(LProjectOptions, IOTAProjectOptionsConfigurations, Result);
  end;
end;

class function TSkOTAHelper.InsertOptionValue(const AValues, AValue,
  ASeparator: string): string;
var
  LValues: TArray<string>;
  I: Integer;
begin
  LValues := AValues.Split([ASeparator], TStringSplitOptions.None);
  try
    for I := 0 to Length(LValues) - 1 do
    begin
      if SameText(LValues[I], AValue) then
      begin
        LValues[I] := AValue;
        Exit;
      end;
    end;
    LValues := LValues + [AValue];
  finally
    if LValues = nil then
      Result := ''
    else
      Result := string.Join(ASeparator, LValues);
  end;
end;

class procedure TSkOTAHelper.MultiSzToStrings(const ADest: TStrings;
  const ASource: PChar);
var
  P: PChar;
begin
  ADest.BeginUpdate;
  try
    ADest.Clear;
    if ASource <> nil then
    begin
      P := ASource;
      while P^ <> #0 do
      begin
        ADest.Add(P);
        P := StrEnd(P);
        Inc(P);
      end;
    end;
  finally
    ADest.EndUpdate;
  end;
end;

class function TSkOTAHelper.RemoveOptionValue(const AValues, AValue,
  ASeparator: string): string;
var
  LValues: TArray<string>;
  LNewValues: TArray<string>;
  I: Integer;
begin
  LNewValues := [];
  LValues := AValues.Split([ASeparator], TStringSplitOptions.None);
  for I := 0 to Length(LValues) - 1 do
    if not SameText(LValues[I], AValue) then
      LNewValues := LNewValues + [LValues[I]];
  if LNewValues = nil then
    Result := ''
  else
    Result := string.Join(ASeparator, LNewValues);
end;

class procedure TSkOTAHelper.StrResetLength(var S: string);
begin
  SetLength(S, StrLen(PChar(S)));
end;

class function TSkOTAHelper.TryCopyFileToOutputPath(const AProject: IOTAProject;
  const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig;
  const AFileName: string): Boolean;
var
  LProjectOutputPath: string;
begin
  Result := False;
  if (APlatform <> TSkProjectPlatform.Unknown) and TFile.Exists(AFileName) and TryGetProjectOutputPath(AProject, APlatform, AConfig, LProjectOutputPath) then
  begin
    try
      if not TDirectory.Exists(LProjectOutputPath) then
        TDirectory.CreateDirectory(LProjectOutputPath);
      TFile.Copy(AFileName, TPath.Combine(LProjectOutputPath, TPath.GetFileName(AFileName)), True);
      Result := True;
    except
      Result := False;
    end;
  end;
end;

class function TSkOTAHelper.TryCopyFileToOutputPathOfActiveBuild(
  const AProject: IOTAProject; const AFileName: string): Boolean;
var
  LPlatform: TSkProjectPlatform;
  LConfig: TSkProjectConfig;
begin
  LPlatform := TSkProjectPlatform.Unknown;
  LConfig := TSkProjectConfig.Release;
  if Assigned(AProject) then
  begin
    LPlatform := TSkProjectPlatform.FromString(AProject.CurrentPlatform);
    LConfig := TSkProjectConfig.FromString(AProject.CurrentConfiguration);
  end;
  Result := TryCopyFileToOutputPath(AProject, LPlatform, LConfig, AFileName);
end;

class function TSkOTAHelper.TryGetBuildConfig(const AProject: IOTAProject;
  const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig;
  out ABuildConfig: IOTABuildConfiguration): Boolean;
var
  LOptionsConfigurations: IOTAProjectOptionsConfigurations;
  LConfigName: string;
  I: Integer;
begin
  Result := False;
  ABuildConfig := nil;
  if APlatform <> TSkProjectPlatform.Unknown then
  begin
    LOptionsConfigurations := GetProjectOptionsConfigurations(AProject);
    if Assigned(LOptionsConfigurations) then
    begin
      LConfigName := AConfig.ToString;
      for I := LOptionsConfigurations.ConfigurationCount - 1 downto 0 do
      begin
        ABuildConfig := LOptionsConfigurations.Configurations[I];
        if ContainsOptionValue(ABuildConfig.Value[sDefine], LConfigName) then
        begin
          ABuildConfig := ABuildConfig.PlatformConfiguration[APlatform.ToString];
          Exit(Assigned(ABuildConfig));
        end;
      end;
    end;
  end;
end;

class function TSkOTAHelper.TryGetProjectOutputPath(const AProject: IOTAProject;
  const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig;
  out AOutputPath: string): Boolean;
var
  LBuildConfig: IOTABuildConfiguration;
begin
  Result := (APlatform <> TSkProjectPlatform.Unknown) and
    TryGetBuildConfig(AProject, APlatform, AConfig, LBuildConfig) and
    TryGetProjectOutputPath(AProject, LBuildConfig, AOutputPath) and
    TPath.HasValidPathChars(AOutputPath, False);
  if not Result then
    AOutputPath := '';
end;

class function TSkOTAHelper.TryGetProjectOutputPath(const AProject: IOTAProject;
  ABuildConfig: IOTABuildConfiguration; out AOutputPath: string): Boolean;
var
  LOptions: IOTAProjectOptions;
  LOptionsConfigurations: IOTAProjectOptionsConfigurations;
  LRelativeOutputPath: string;
begin
  Result := False;
  try
    if Assigned(AProject) then
    begin
      AOutputPath := TPath.GetDirectoryName(AProject.FileName);
      LOptions := AProject.ProjectOptions;
      if LOptions <> nil then
      begin
        if not Assigned(ABuildConfig) then
        begin
          LOptionsConfigurations := GetProjectOptionsConfigurations(AProject);
          if Assigned(LOptionsConfigurations) then
            ABuildConfig := LOptionsConfigurations.ActiveConfiguration;
        end;

        if Assigned(ABuildConfig) then
        begin
          LRelativeOutputPath := LOptions.Values[OutputDirPropertyName];
          AOutputPath := ExpandOutputPath(ExpandPath(AOutputPath, LRelativeOutputPath), ABuildConfig);
          Result := True;
        end
        else
          Result := False;
      end
      else
        Result := True;
    end;
  finally
    if not Result then
      AOutputPath := '';
  end;
end;

class function TSkOTAHelper.TryGetProjectOutputPathOfActiveBuild(
  const AProject: IOTAProject; out AOutputPath: string): Boolean;
var
  LPlatform: TSkProjectPlatform;
  LConfig: TSkProjectConfig;
begin
  LPlatform := TSkProjectPlatform.Unknown;
  LConfig := TSkProjectConfig.Release;
  if Assigned(AProject) then
  begin
    LPlatform := TSkProjectPlatform.FromString(AProject.CurrentPlatform);
    LConfig := TSkProjectConfig.FromString(AProject.CurrentConfiguration);
  end;
  Result := TryGetProjectOutputPath(AProject, LPlatform, LConfig, AOutputPath);
end;

class function TSkOTAHelper.TryRemoveOutputFile(const AProject: IOTAProject;
  const APlatform: TSkProjectPlatform; const AConfig: TSkProjectConfig;
  AFileName: string): Boolean;
var
  LProjectOutputPath: string;
begin
  Result := False;
  if (APlatform <> TSkProjectPlatform.Unknown) and TSkOTAHelper.TryGetProjectOutputPathOfActiveBuild(AProject, LProjectOutputPath) then
  begin
    AFileName := TPath.Combine(LProjectOutputPath, AFileName);
    if TFile.Exists(AFileName) then
    begin
      try
        TFile.Delete(AFileName);
        Result := True;
      except
        Result := False;
      end;
    end;
  end;
end;

class function TSkOTAHelper.TryRemoveOutputFileOfActiveBuild(
  const AProject: IOTAProject; const AFileName: string): Boolean;
var
  LPlatform: TSkProjectPlatform;
  LConfig: TSkProjectConfig;
begin
  LPlatform := TSkProjectPlatform.Unknown;
  LConfig := TSkProjectConfig.Release;
  if Assigned(AProject) then
  begin
    LPlatform := TSkProjectPlatform.FromString(AProject.CurrentPlatform);
    LConfig := TSkProjectConfig.FromString(AProject.CurrentConfiguration);
  end;
  Result := TryRemoveOutputFile(AProject, LPlatform, LConfig, AFileName);
end;

{ TSkia4DelphiProject }

class procedure TSkia4DelphiProject.FindPath(out APath, AAbsolutePath: string);
begin
  AAbsolutePath := TSkOTAHelper.GetEnvironmentVar(SkiaDirVariable, True);
  if IsValidSkiaDir(AAbsolutePath) then
    APath := '$(' + SkiaDirVariable + ')'
  else
  begin
    APath := '';
    AAbsolutePath := '';
  end;
end;

class function TSkia4DelphiProject.GetAbsolutePath: string;
begin
  if not FPathChecked then
    GetPath;
  Result := FAbsolutePath;
end;

class function TSkia4DelphiProject.GetDeployFiles(
  const APlatform: TSkProjectPlatform): TArray<TSkDeployFile>;
var
  I: Integer;
begin
  Result := [];
  for I := Low(DeployFile) to High(DeployFile) do
    if DeployFile[I].Platform = APlatform then
      Result := Result + [DeployFile[I]];
end;

class function TSkia4DelphiProject.GetFound: Boolean;
begin
  Result := not Path.IsEmpty;
end;

class function TSkia4DelphiProject.GetPath: string;
begin
  if not FPathChecked then
  begin
    FindPath(FPath, FAbsolutePath);
    FPathChecked := True;
  end;
  Result := FPath;
end;

class function TSkia4DelphiProject.IsValidSkiaDir(const APath: string): Boolean;
begin
  Result := TDirectory.Exists(APath);
end;

{ Register }

procedure Register;
begin
  ForceDemandLoadState(dlDisable);
  TSkProjectMenuCreatorNotifier.Register;
  TSkCompileNotifier.Register;
end;

end.
