unit epPipe;

interface
uses
  dvcrt,
  dvwin,
  dvinet,
  minireg,
  epvars,
  synacode,
  windows,
  sysUtils,
  Classes,
  strUtils;

var
    InputPipeRead, InputPipeWrite: THandle;
    OutputPipeRead, OutputPipeWrite: Cardinal;
    ErrorPipeRead, ErrorPipeWrite: THandle;

function executarAcesso (app: String): boolean;
function ReadPipeHasData(whatPipe: THandle): boolean;
function ReadPipeInput(InputPipe: THandle): String;
function WritePipeOut(OutputPipe: THandle; InString: string) : string;
function getPipedData: string;
procedure progStop;

implementation
var
    ProcessInfo : TProcessInformation;


{----------------------------------------------------------------------}
{                      Para execução do pipe                           }
{----------------------------------------------------------------------}

procedure progStop;
begin
    WritePipeOut(InputPipeWrite, 'quit' + #$0a);

    // close pipe handles
    CloseHandle(InputPipeRead);
    CloseHandle(InputPipeWrite);
    CloseHandle(OutputPipeRead);
    CloseHandle(OutputPipeWrite);
    CloseHandle(ErrorPipeRead);
    CloseHandle(ErrorPipeWrite);

    // close process handles
    CloseHandle(ProcessInfo.hProcess);
    TerminateProcess(ProcessInfo.hProcess, 0);
end;

{----------------------------------------------------------------------}
{               Verifica se chegaram dados do Pipe                     }
{----------------------------------------------------------------------}

function ReadPipeHasData(whatPipe: THandle): boolean;
var numBytes: Cardinal;
begin
    PeekNamedPipe(whatPipe, nil, 0, nil, @numBytes, NIL);
    result := numBytes > 0;
end;

{----------------------------------------------------------------------}
{                  Executa arquivo de comando PSFTP                    }
{----------------------------------------------------------------------}

function ReadPipeInput(InputPipe: THandle): String;
var
    TextBuffer: array[0..32767] of char;
    BytesRead: Cardinal;
begin
    Result := '';
    PeekNamedPipe(InputPipe, nil, Sizeof(TextBuffer)-1, @BytesRead, NIL, NIL);

    if BytesRead > 0 then
        begin
            ReadFile(InputPipe, TextBuffer, Sizeof(TextBuffer)-1, BytesRead, NIL);
            TextBuffer [BytesRead] := #$0;
            Result := strPas(TextBuffer);
        end;
end;

{----------------------------------------------------------------------}
{                  Escrever no pipe do psftp                           }
{----------------------------------------------------------------------}

function WritePipeOut(OutputPipe: THandle; InString: string) : string;
var
    byteswritten: DWord;
begin
    WriteFile (OutputPipe, Instring[1], Length(Instring), byteswritten, nil);
    Result := ReadPipeInput(OutputPipeRead);
end;

{----------------------------------------------------------------------}
{                 pega várias linhas vindas do servidor                }
{----------------------------------------------------------------------}

function getPipedData: string;
begin
    repeat
        delay(800);
        sintClek;
    until ReadPipeHasData(OutputPipeRead);

    Result := ReadPipeInput(OutputPipeRead);
end;

{----------------------------------------------------------------------}
{                  Executa protocolo SFTP ou FTP                       }
{----------------------------------------------------------------------}

function executarAcesso (app: String): boolean;
var
    Security : TSecurityAttributes;
    start : TStartUpInfo;
begin
    Result := false;

    With Security do
        begin
            nLength := SizeOf(TSecurityAttributes) ;
            bInheritHandle := true;
            lpSecurityDescriptor := NIL;
        end;

    CreatePipe(InputPipeRead, InputPipeWrite, @Security, 0);
    CreatePipe(OutputPipeRead, OutputPipeWrite, @Security, 0);
    CreatePipe(ErrorPipeRead, ErrorPipeWrite, @Security, 0);

    FillChar(Start,Sizeof(Start),#0) ;
    start.cb := SizeOf(start) ;
    start.hStdInput := InputPipeRead;
    start.hStdOutput := OutputPipeWrite;
    start.hStdError :=  ErrorPipeWrite;
    start.dwFlags := STARTF_USESTDHANDLES + STARTF_USESHOWWINDOW;
    start.wShowWindow := SW_HIDE;

    Result := CreateProcess(nil, PChar(app),
        @Security, @Security,
        true,
        CREATE_NEW_CONSOLE or SYNCHRONIZE, nil, nil, start, ProcessInfo);
end;
end.
