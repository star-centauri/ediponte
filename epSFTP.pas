unit epSFTP;

interface
uses
  dvcrt,
  dvwin,
  dvform,
  minireg,
  epError,
  epvars,
  epMsg,
  synacode,
  windows,
  sysUtils,
  Classes,
  strUtils;

function executarSFTP (ponte: TPonte): boolean;
function executarLoginSFTP(ponte: TPonte): boolean;

implementation
var
    InputPipeRead, InputPipeWrite: THandle;
    OutputPipeRead, OutputPipeWrite: Cardinal;
    ErrorPipeRead, ErrorPipeWrite: THandle;
    ProcessInfo : TProcessInformation;

{----------------------------------------------------------------------}
{                 pega várias linhas vindas do servidor                }
{----------------------------------------------------------------------}

function getPipedData: string;
var response: string;
begin
    response := '';
    while not ReadPipeHasData(OutputPipeRead) do
        begin
            delay (300);
            sintClek;
        end;
    repeat
        Delay(800);
        response := response + ReadPipeInput(OutputPipeRead);
    until not ReadPipeHasData(OutputPipeRead);
    result := response;
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
            TextBuffer [bytesRead] := #$0;
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
{                  Executa a inicialização do servidor                 }
{----------------------------------------------------------------------}

function executarSFTP (ponte: TPonte): boolean;
var
    app, connect: String;
    Security : TSecurityAttributes;
    start : TStartUpInfo;
begin
    connect := ponte.Conta + '@' + ponte.Servidor;
    app := 'psftp.exe ' + connect;

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

{----------------------------------------------------------------------}
{                   Faz o acesso a conta do usuário                    }
{----------------------------------------------------------------------}

function executarLoginSFTP(ponte: TPonte): boolean;
var
    response; string;
begin
    Result := false;

    response := getPipedData;
    if pos('Store key in cache?', response) <> 0 then
        begin
            WritePipeOut(InputPipeWrite, 'y' + #$0a);
            response := getPipedData;
        end;

    if (pos('password', response) <> 0) or
       (pos('Senha', response) <> 0) then
        begin
            senha := aplicaSenha(ponte.Senha);
            WritePipeOut(InputPipeWrite, senha + #$0a);

            response := ReadPipeInput(ErrorPipeRead);
            if pos('Fatal', response) <> 0 then
                begin
                    sintWrite('Acesso a conta bloqueado.');
                    exit;
                end;

            response := getPipedData;
            if pos('denied', response) <> 0 then
                ERRO := ERRO_CONTA
            else
                begin
                    WritePipeOut(InputPipeWrite, 'cd ' + rotaAtual + #$0a);
                    Result := true;
                end;
        end
    else
        begin
           ERRO := ERRO_CONEXAO;
           progStop;
        end;
end;

end.
