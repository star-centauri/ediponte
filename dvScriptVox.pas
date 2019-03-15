unit dvScriptVox;

interface
uses
  dvcrt,
  dvwin,
  dvform,
  dvinet,
  dvssl,
  minireg,
  epvars,
  epMsg,
  epError,
  epeditor,
  classes,
  synacode,
  windows,
  sysUtils,
  strUtils;

{ Configurações da rotina ScriptVox }
function inicializaScriptVox(ponte: TPonte; nomePonte: string): Boolean;
procedure fechaScriptVox;
function createRotaScriptVox(caminho: string): Boolean;
function executaOpcaoScripVox(opcao: string; out prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;

{ funções e procedures para manipulação de arquivos }
function opcoesArqScripVox(listaOpcoes: TStringList;  var tabLetrasOpcao: string): Boolean;
function _FileExistsScripVox(fileName: string): Boolean;
function _findFirstScripVox(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec): integer;
function _findNextScripVox(var SearchResults: TSearchRec): integer;
procedure _assignFileScripVox(var arq: TextFile; nomeArq: string);
function _ioresultScripVox(ponte: TPonte): integer;
procedure _closeFileScripVox(var FileHandle: TextFile);
procedure _resetScripVox(var FileHandle: TextFile);

{ funções e procedures para manipulação de pastas }
function _directoryexistScripVox: Boolean;
procedure _ChDirScripVox(Dir: string);
procedure opcoesDirScriptVox(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
function voltarDirScripVox: Boolean;

implementation
var
    InputPipeRead, InputPipeWrite: THandle;
    OutputPipeRead, OutputPipeWrite: Cardinal;
    ErrorPipeRead, ErrorPipeWrite: THandle;
    ProcessInfo : TProcessInformation;
    rotaAtual, tipoScript: string;
    ponteConectadaScript: TPonte;


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
{               Verifica se chegaram dados do Pipe                     }
{----------------------------------------------------------------------}

function ReadPipeHasData(whatPipe: THandle): boolean;
var numBytes: Cardinal;
begin
    PeekNamedPipe(whatPipe, nil, 0, nil, @numBytes, NIL);
    result := numBytes > 0;
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
{                      Para execução do pipe                           }
{----------------------------------------------------------------------}

procedure progStop;
begin
    //WritePipeOut(InputPipeWrite, 'quit' + #$0a);

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
{               Executa a inicialização do servidor                    }
{----------------------------------------------------------------------}

function executarDropboxApi (): boolean;
var
    app: String;
    Security : TSecurityAttributes;
    start : TStartUpInfo;
begin
    app := '.\pyApis\dbxPonte.exe';

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
{       Cria caminho de rota de acordo com servidor ScriptVox          }
{----------------------------------------------------------------------}

function createRotaScriptVox(caminho: string): Boolean;
var
    p: integer;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            p := pos('@', caminho);
            rotaAtual := 'c:\Users\' + ponteConectadaScript.Conta + '\' + 'Dropbox\';

            if p <> 0 then
                begin
                    rotaAtual := rotaAtual + copy(caminho, p-1, Length(caminho)+1);
                    Result := true;
                end
            else
                Result := true;
        end
end;

{----------------------------------------------------------------------}
{            Ver o tipo do serviço e envia para o respectivo           }
{            script para verificar se existe o diretório               }
{----------------------------------------------------------------------}

function _directoryexistScripVox: Boolean;
begin
    if tipoScript = 'DROPBOX' then
        Result := DirectoryExists(rotaAtual);
end;

{----------------------------------------------------------------------}
{            Ver o tipo do serviço e envia para o respectivo           }
{            script para verificar se existe o arquivo                 }
{----------------------------------------------------------------------}

function _FileExistsScripVox(fileName: string): Boolean;
begin
    if tipoScript = 'DROPBOX' then
        Result := FileExists(fileName);
end;

{----------------------------------------------------------------------}
{              função findFirst para protocolo scriptVox               }
{----------------------------------------------------------------------}

function _findFirstScripVox(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec): integer;
begin
    if tipoScript = 'DROPBOX' then
        begin
            SetCurrentDir(rotaAtual);
            Result := FindFirst(FileMask, Attributes, SearchResult);
        end
end;

function _findNextScripVox(var SearchResults: TSearchRec): integer;
var
    retorno: integer;
begin
     if tipoScript = 'DROPBOX' then
         begin
             repeat
                 retorno := FindNext(SearchResults);
             until ((SearchResults.Name <> '.dropbox') and
                   (SearchResults.Name <> '.dropbox.cache') and
                   (SearchResults.Name <> 'desktop.ini')) or (retorno > 0);

             if pos('.', SearchResults.Name) = 0 then
                 begin
                     SearchResults.Name := SearchResults.Name + ' Diretório';
                     StrPCopy(SearchResults.FindData.cFileName, SearchResults.Name);
                 end;

             Result := retorno;
         end
end;

procedure _ChDirScripVox(Dir: string);
begin
    if ponteConectadaScript.Tipo = 'DROPBOX' then
        begin
            if rotaAtual[length(rotaAtual)] <> '\' then
                rotaAtual := rotaAtual + '\';
                
            rotaAtual := rotaAtual + Dir;
            ChDir(rotaAtual);
        end
end;

function voltarDirScripVox: Boolean;
var
    copyRota: string;
    p: integer;
begin
    Result := false;

    if ponteConectadaScript.Tipo = 'DROPBOX' then
        begin
            copyRota := copy(rotaAtual, 1, length(rotaAtual)-1);

            p := Pos('\', copyRota);
            while p <> 0 do
                begin
                    delete(copyRota, 1, p);
                    p := Pos('\', copyRota);
                end;

            p := length(rotaAtual) - length(copyRota) - 1;
            rotaAtual := copy(rotaAtual, 1, p);

            if pos('Dropbox\', rotaAtual) <> 0 then
                Result := true;
        end;
end;

function criarArq: Boolean;
var
   novoArq: string;
   arq: Text;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            SetCurrentDir(rotaAtual);
            sintWriteLn('Informe o nome do novo arquivo: ');
            sintReadLn(novoArq);

            AssignFile(arq, novoArq);

            if FileExists(novoArq) then
                sintWrite('Arquivo com o nome ' + novoArq + ' já existe')
            else
                begin
                    Rewrite(arq);
                    sintWrite('Arquivo criado com sucesso');
                    Result := true;
                end;

            CloseFile(arq);
        end
end;

function copiarArq: Boolean;
var
    copiarArq, nomeArq: string;
    p: integer;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            if GetCurrentDir <> rotaAtual then
                SetCurrentDir(rotaAtual);

            sintWriteLn('Informe o arquivo que deseja copiar (rota completa): ');
            sintReadLn(copiarArq);

            nomeArq := copy(copiarArq, 1, length(copiarArq));

            p := Pos('\', nomeArq);
            while p <> 0 do
                begin
                    delete(nomeArq, 1, p);
                    p := Pos('\', nomeArq);
                end;

            if CopyFile(PChar(copiarArq), PChar(rotaAtual + '\' + nomeArq), true) then
                begin
                    sintWriteLn('Arquivo copiado com sucesso');
                    Result := true;
                end
            else
                sintWriteLn('Arquivo já existe no diretório atual.');
        end
end;

function criarPasta: Boolean;
var
    nomeDir: string;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            sintWriteln('Informe o nome da nova pasta: ');
            sintReadLn(nomeDir);

            if rotaAtual[length(rotaAtual)] <> '\' then
                rotaAtual := rotaAtual + '\';

            if DirectoryExists(rotaAtual + nomeDir) then
                sintWriteLn('O diretório com o nome ' + nomeDir + ' já existe')
            else
                begin
                    ForceDirectories(rotaAtual + nomeDir + '\');
                    Result := true;
                end;
        end
end;

function removerPasta: Boolean;
var
   dirDeletar: string;
   c: char;
   i: integer;
   sr: TSearchRec;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            if GetCurrentDir <> rotaAtual then
                SetCurrentDir(rotaAtual);

            sintWriteLn('Informe o nome do diretório que será removido: ');
            sintReadLn(dirDeletar);

            if DirectoryExists(dirDeletar) then
                begin

                    if FindFirst(rotaAtual + dirDeletar + '\*.*', faAnyFile, SR) = 0 then
                        begin
                            repeat
                                if ((sr.Name <> '.') and (sr.Name <> '..')) then
                                   begin
                                       sintWriteLn('O diretório possui arquivos e pastas.');
                                       sintWriteLn('Remova-os antes de excluir diretório desejado.');
                                       exit;
                                   end;
                            until FindNext(SR) <> 0;

                            FindClose(SR);
                        end;

                    RemoveDir(dirDeletar);
                    SetCurrentDir(rotaAtual);
                    Result := true;
                    sintWriteLn('Diretório removido com sucesso');
                end
            else
                sintWriteLn('Diretório ' + dirDeletar + ' não existe.');
        end
end;

function deletaArq(nomeArq: string): Boolean;
var c: char;
begin
   Result := false;

   if tipoScript = 'DROPBOX' then
       begin
            sintWrite('Deseja realmente remover o arquivo?');
            c := popupMenuPorLetra('SN');

            if UpperCase(c) = 'S' then
                begin
                    if GetCurrentDir <> rotaAtual then
                        SetCurrentDir(rotaAtual);

                    if FileExists(nomeArq) then
                        begin
                            DeleteFile(nomeArq);
                            Result := true;
                        end
                    else
                        sintWriteLn('O arquivo ' + nomeArq + ' não existe no diretório atual.');

                end;
       end
end;

function reomearArq(nomeArq: string): Boolean;
var novoNome: string;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            if GetCurrentDir <> rotaAtual then
                SetCurrentDir(rotaAtual);

            sintWriteLn('Informe o novo nome: ');
            sintReadLn(novoNome);

            if FileExists(nomeArq) then
                begin
                    if RenameFile(nomeArq, novoNome) then
                        result := true
                    else
                        sintWrite('Houve um erro ao mudar o nome, tente novamente.');
                end
            else
                sintWriteLn('Arquivo não existe.');

        end
end;

function opcoesArqScripVox(listaOpcoes: TStringList;  var tabLetrasOpcao: string): Boolean;
begin
    Result := true;
    tabLetrasOpcao := 'EDRT' + ESC;

    if tipoScript = 'DROPBOX' then
        begin
            listaOpcoes.Add('E - Editar Arquivo');
            listaOpcoes.Add('D - Deletar Arquivo');
            listaOpcoes.Add('R - Renomear Arquivo');
            listaOpcoes.Add('T - Terminar');
        end
    else
        Result := false;
end;

procedure opcoesDirScriptVox(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
begin
    tabLetrasOpcao := 'NCPRT' + ESC;

    if tipoScript = 'DROPBOX' then
        begin
            listaOpcoes.Add('N - Novo Arquivo');
            listaOpcoes.Add('C - Copiar arquivo local para o dropbox');
            listaOpcoes.Add('P - Criar pasta');
            listaOpcoes.Add('R - Remover pasta');
            listaOpcoes.Add('T - Terminar');
        end
end;

function executaOpcaoScripVox(opcao: string; out prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;
begin
    Result := false;

    if tipoDado = Arquivo then
        if opcao = 'E' then
           begin
               if EditarArq(nomeArq) then
                    prosseguir := false;
           end
        else
        if opcao = 'D' then
            begin
                if not deletaArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        //else
        //if opcao = 'P' then naoImplem
        else
        if opcao = 'R' then
            begin
                if not reomearArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        else
        if (opcao = ESC) or (opcao = 'T') then
            begin
                limpaBaixo(WhereY);
                prosseguir := false;
                result := false;
                opcao := 'N';
            end
        else
            ERRO := ERRO_OPCINV
    else
    if tipoDado = Diretorio then
        if opcao = 'N' then
            begin
                if not criarArq then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'C' then
            begin
                if not copiarArq then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'P' then
            begin
                if not criarPasta then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'R' then
            begin
                if not removerPasta then
                    Result := false;
                prosseguir := false;
            end
        else
        if (opcao = ESC) or (opcao = 'T') then
            begin
                limpaBaixo(WhereY);
                prosseguir := false;
                result := false;
                opcao := 'N';
            end
        else
            ERRO := ERRO_OPCINV
    else
        sintWriteLn('Tipo de Dado inválido.');
end;

procedure _assignFileScripVox(var arq: TextFile; nomeArq: string);
begin
     if tipoScript = 'DROPBOX' then
         AssignFile(arq, nomeArq);
end;

function _ioresultScripVox(ponte: TPonte): integer;
begin
    if tipoScript = 'DROPBOX' then
        Result := IOResult;
end;

procedure _closeFileScripVox(var FileHandle: TextFile);
begin
    if tipoScript = 'DROPBOX' then
        begin
            //CloseFile(FileHandle);
        end;
end;

procedure _resetScripVox(var FileHandle: TextFile);
begin
    if tipoScript = 'DROPBOX' then
        Reset(FileHandle);
end;

function inicializaScriptVox(ponte: TPonte; nomePonte: string): Boolean;
var
    response: string;
begin
    Result := true;

    if (ponte.Conta <> '') and
       (ponte.Servidor <> '') and
       (ponte.Tipo <> '') then
        begin
            ponteConectadaScript := ponte;
            tipoScript := ponte.Tipo;
            createRotaScriptVox(nomePonte);

            if not executarDropboxApi then
                begin
                    ERRO := ERRO_CONEXAO;
                    progStop;
                    exit;
                end;

            WritePipeOut(InputPipeWrite, 'login' + #$0a);
            response := getPipedData;

            sintetiza('ponte '+ ponte.Tipo + ' conectada.');
        end
    else
        Result := false;
end;

procedure fechaScriptVox;
begin
    if tipoScript = 'DROPBOX' then
        rotaAtual := '';
end;
end.
