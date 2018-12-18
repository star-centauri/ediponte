unit dvFTP;

interface
uses
  dvcrt,
  dvwin,
  dvform,
  dvinet,
  minireg,
  epError,
  epvars,
  epMsg,
  epeditor,
  epSFTP,
  epFTP,
  synacode,
  windows,
  sysUtils,
  Classes,
  strUtils;

{ Configurações da rotina FTP }
procedure inicializaFTP(ponte: TPonte; nomePonte: string);
procedure fechaFTP;
function createRotaFTP(caminho: string): Boolean;
function listarArqFTP(out listar: TStringList): Boolean;
function executaOpcaoFTP(opcao: string; out prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;

{ funções e procedures para manipulação de arquivos }
procedure opcoesArqFTP(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
function downloadFileFTP(nomeArqBaixar, dir: string): Boolean;
function _FileExistsFTP(fileName: string): Boolean;
procedure _resetFTP (var FileHandle: TextFile);
function _findFirstFTP(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec; listar: TStringList): integer;
function _findNextFTP(var SearchResults: TSearchRec; listar: TStringList): integer;
procedure _assignFileFTP(var arq: TextFile; nomeArq: string);
function _ioresultFTP: Integer;
procedure _closeFileFTP(var FileHandle: TextFile);

{ funções e procedures para manipulação de pastas }
procedure opcoesDirFTP(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
function voltarDirFTP: Boolean;
function _directoryExistFTP: Boolean;
procedure _ChDirFTP(Dir: string);

implementation
var
    InputPipeRead, InputPipeWrite: THandle;
    OutputPipeRead, OutputPipeWrite: Cardinal;
    ErrorPipeRead, ErrorPipeWrite: THandle;
    ProcessInfo : TProcessInformation;
    rotaAtual, nomeArqConectado: string;
    ponteConectadaFTP: TPonte;
    editarRemotamente: boolean;

{----------------------------------------------------------------------}
{          Cria caminho de rota de acordo com servidor FTP             }
{----------------------------------------------------------------------}

function createRotaFTP(caminho: string): Boolean;
var
    p: integer;
begin
    Result := false;
    if (ponteConectadaFTP.Porta <> 21) and
       (ponteConectadaFTP.Porta <> 22) then
        begin
            sintWrite('Porta FTP inválida, só é aceita porta 21 ou 22.');
            exit;
        end;

    p := pos('@', caminho);
    rotaAtual := 'public_html';
    if (p <> 0) and (caminho <> '') then
        begin
            rotaAtual := rotaAtual + '/' + copy(caminho, p+1, Length(caminho));
            rotaAtual := StringReplace(rotaAtual, '\', '/', [rfReplaceAll, rfIgnoreCase]);
            Result := true;
        end
    else
        Result := true;
end;

{----------------------------------------------------------------------}
{        Extrai dados relevantes do response de conexão HTTP           }
{----------------------------------------------------------------------}

function extrairDados(s: string): string;
var
    p, i, j: integer;
    tam, dados, aux: string;
begin
    dados := '';
    j := 0;

    //Saber se é diretótio
    p := Pos('drwxr', s);
    if (p <> 0) and (pos(' ..', s) = 0) and (pos(' .', s) = 0) then dados := 'dir|';
    delete(s, 1, p);

    While true do
        begin
            p := Pos(' ', s);
            aux := copy(s, 1, p);

            if aux <> ' ' then
                if j = 4 then
                    break
                else
                    j := j + 1;
            delete(s, 1, p);
        end;

    //extrai o tamanho
    p := Pos(' ', s);
    tam := trim(copy(s, 1, p-1));
    if tam <> '' then
      if tam[1] in ['0'..'9'] then
          begin
              tam := trim(copy(tam, 1, length(tam)));
              dados := dados + IntToStr(round(pegaReal(tam)));
          end
      else
          dados := dados + IntToStr(-1);

    // extrai a data
    delete(s, 1, p);
    dados := dados + '|' + trim(copy(s, 1, 12));

    // extrai o nome
    delete (s, 1, 13);
    dados := dados + '|' + copy(s, 1, Length(s));

    extrairDados := dados;
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
{                  Executa protocolo SFTP ou FTP                       }
{----------------------------------------------------------------------}

function executarAcesso (ponte: TPonte): boolean;
var
    app: String;
    Security : TSecurityAttributes;
    start : TStartUpInfo;
begin
    Result := false;

    if ponte.Porta = 21 then
        app := executarFTP(ponte)
    else
    if ponte.Porta = 22 then
        app := executarSFTP(ponte)
    else
        exit;

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
{                      Acessar conta do Servidor                       }
{----------------------------------------------------------------------}

function ContaESenha(ponte: TPonte): Boolean;
var
    response, senha: string;
begin
    Result := false;

    if not executarAcesso(ponte) then
        begin
            ERRO := ERRO_CONEXAO;
            progStop;
            exit;
        end;

    response := getPipedData;
    if pos('Store key in cache?', response) <> 0 then
        begin
            WritePipeOut(InputPipeWrite, 'y' + #$0a);
            response := getPipedData;
        end;

    if ponte.Porta = 21 then
        begin
            if pos('Usu', response) <> 0 then
                begin
                    WritePipeOut(InputPipeWrite, ponte.Conta + #$0a);
                    response := getPipedData;

                    if pos('Senha', response) <> 0 then
                        begin
                            senha := aplicaSenha(ponte.Senha);
                            response := WritePipeOut(InputPipeWrite, senha + #$0a);

                            if response <> '' then
                                begin
                                    response := WritePipeOut(InputPipeWrite, 'cd ' + rotaAtual + #$0a);
                                    Result := true;
                                end;

                            //response := ReadPipeInput(ErrorPipeRead);
                            //response := getPipedData;
                        end;
                end
            else
                begin
                    ERRO := ERRO_CONEXAO;
                    progStop;
                end;
        end
    else
    if ponte.Porta = 22 then
        begin
            if pos('password', response) <> 0 then
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
end;

{----------------------------------------------------------------------}
{              Ver se diretório existe no servidor FTP                 }
{----------------------------------------------------------------------}

function _directoryExistFTP: Boolean;
var
    p: integer;
    recurso: string;
begin
    Result := false;

    if (ponteConectadaFTP.Porta <> 21) and
       (ponteConectadaFTP.Porta <> 22) then
        exit;

    recurso := 'cd ' + rotaAtual;
    WritePipeOut(InputPipeWrite, recurso + #$0a);

    if (ponteConectadaFTP.Porta = 21) and
       (pos('250', getPipedData) <> 0) then
        Result := true
    else
    if (ponteConectadaFTP.Porta = 22) and
       (pos('Remote directory is now', getPipedData) <> 0) then
        Result := true;
end;

{----------------------------------------------------------------------}
{               Ver se arquivo existe no servidor FTP                  }
{----------------------------------------------------------------------}

function _FileExistsFTP(fileName: string): Boolean;
var
    response, fileExist: string;
    p: integer;
begin
    Result := false;

    p := pos('/', fileName);
    if p <> 0 then
       while pos('/', fileName) <> 0 do
           delete(fileName, 1, pos('/', fileName));

    fileExist := '*' + fileName;
    WritePipeOut(InputPipeWrite, 'ls ' + fileExist + #$0a);

    response := getPipedData;
    if pos(fileName, response) <> 0 then
        Result := true;
end;

{----------------------------------------------------------------------}
{           Retorna valor do response da busca pela conta              }
{----------------------------------------------------------------------}

function listarArqFTP(out listar: TStringList): Boolean;
var
    List: TStringList;
    response: string;
    i: integer;
begin
    Result := true;
    WritePipeOut(InputPipeWrite, 'dir' + #$0a);
    response := getPipedData;

    if response <> '' then
        begin
            List := TStringList.Create;

            ExtractStrings([#$D, #$A], [], PChar(response), List);
            if List.Count = 1 then
                begin
                    ERRO := ERRO_NEXISDIR;
                    Result := false;
                    exit;
                end;

            for i := 0 to (List.Count-1) do
                if (pos('idea', List[i]) = 0) and
                   (pos('cache', List[i]) = 0) and
                   (pos('Listing directory', List[i]) = 0) and
                   (pos('Remote directory', List[i]) = 0)then
                    listar.Add(extrairDados(List[i]));
        end;
end;

{----------------------------------------------------------------------}
{                função findFirst para protocolo FTP                   }
{----------------------------------------------------------------------}

function _findFirstFTP(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec; listar: TStringList): integer;
var
   dir, item, aux: string;
   p, lengthDir: integer;
begin
    ponteiro_prox := 1;
    lengthDir := listar.Count;
    dir := '';

    if lengthDir = 0 then
        begin
            ERRO := ERRO_CONEXAO;
            Result := 1;
            exit;
        end;

    if (FileMask = '*') or
       (FileMask = '?') or
       (FileMask = '*.*') or
       (FileMask = '*.**') then
        begin
            aux := listar[ponteiro_prox];

            //Saber se é diretório
            p := Pos('dir|', aux);
            if p <> 0 then dir := ' Diretório';
            delete(aux, 1, p+3);

            //Pegar tamanho
            p := Pos('|', aux);
            item := copy(aux, 1, p-1);
            SearchResult.Size := StrToInt(item);
            delete(aux, 1, p+1);

            //Pegar nome
            p := Pos('|', aux);
            item := copy(aux, p+1, Length(aux));
            if item <> '..' then item := item + dir;
            SearchResult.Name := item;
            StrPCopy(SearchResult.FindData.cFileName, item);
        end;
    Result := 0;
end;

function _findNextFTP(var SearchResults: TSearchRec; listar: TStringList): integer;
var
   dir, item, aux: string;
   p: integer;
begin
    if ponteiro_prox = (listar.Count - 1) then
        Result := 1
    else
        begin
            aux := listar[ponteiro_prox];

            //Saber se é diretório
            p := Pos('dir|', aux);
            if p <> 0 then
                begin
                    dir := ' Diretório';
                    delete(aux, 1, p+3);
                end;

            //Pegar tamanho
            p := Pos('|', aux);
            item := copy(aux, 1, p-1);
            SearchResults.Size := StrToInt(item);
            delete(aux, 1, p+1);

            //Pegar nome
            p := Pos('|', aux);
            item := copy(aux, p+1, Length(aux));
            item := item + dir;
            SearchResults.Name := item;
            StrPCopy(SearchResults.FindData.cFileName, item);

            Result := 0;
        end;
end;

procedure _ChDirFTP(Dir: string);
begin
    rotaAtual := rotaAtual + '/' + Dir;
    WritePipeOut(InputPipeWrite, ('cd ' + Dir + #$0a));
end;

function voltarDirFTP: Boolean;
var
    copyRota: string;
    p: integer;
begin
    Result := false;
    copyRota := copy(rotaAtual, 1, length(rotaAtual)-1);

    p := Pos('/', copyRota);
    while p <> 0 do
        begin
            delete(copyRota, 1, p);
            p := Pos('/', copyRota);
        end;

    p := length(rotaAtual) - length(copyRota) - 1;
    rotaAtual := copy(rotaAtual, 1, p);

    if pos('public_html/', rotaAtual) <> 0 then
        begin
            Result := true;
            WritePipeOut(InputPipeWrite, 'cd ..' + #$0a);
        end;
end;

function enviarArq: Boolean;
var
    response, caminhoArq, nomeArq: string;
    p: integer;
begin
    Result := false;                                                                                     
    sintWriteLn('Informe o arquivo (caminho completo): ');
    sintReadLn(caminhoArq);

    nomeArq := copy(caminhoArq, 1, length(caminhoArq));

    p := Pos('\', nomeArq) or Pos('/', nomeArq);
    while p <> 0 do
        begin
            delete(nomeArq, 1, p);
            p := Pos('\', nomeArq) or Pos('/', nomeArq);
        end;

    p := length(caminhoArq) - length(nomeArq) - 1;
    caminhoArq := copy(caminhoArq, 1, p);

    if pos(' ', caminhoArq) <> 0 then
        caminhoArq := '"' + caminhoArq + '"';
    WritePipeOut(InputPipeWrite, ('lcd ' + caminhoArq + #$0a));
    response := getPipedData;

    if pos('New local directory', response) <> 0 then
        begin
            if pos(' ', nomeArq) <> 0 then
                nomeArq := '"' + nomeArq + '"';

            if _FileExistsFTP(nomeArq) then
                begin
                    sintWriteLn('Arquivo já existe no diretório remoto atual.');
                    sintWrite('Deseja substituir? ');

                    if popupMenuPorLetra('SN') = 'N' then
                        exit;
                end;

            WritePipeOut(InputPipeWrite, 'put ' + nomeArq + #$0a);
            response := getPipedData;

            if pos('remote', response) <> 0 then
                begin
                    sintWrite('Arquivo enviado com sucesso.');
                    Result := true;
                end
            else
                begin
                    sintWriteLn('O arquivo ' + nomeArq + ' não existe neste diretório local.');
                    ERRO := ERRO_NEXISARQ;
                end;
        end
    else
        begin
            sintWriteLn('O sistema não consegue encontar o diretório ' + caminhoArq);
            ERRO := ERRO_NEXISDIR;
        end;
end;

function criarDir: Boolean;
var
    response, novoDir: string;
begin
    Result := false;

    sintWriteLn('Informe o nome do novo diretório: ');
    sintReadLn(novoDir);

    WritePipeOut(InputPipeWrite, ('mkdir ' + novoDir + #$0a));
    response := getPipedData;

    if pos('OK', response) <> 0 then
        begin
            sintWrite('Diretório criado com sucesso.');
            Result := true;
        end
    else
        ERRO := ERRO_CONEXAO;
end;

function removerDir: Boolean;
var 
    response, deletaDir: string;
    c: char;
begin
    Result := false;

    sintWriteLn('Informe o nome do diretório que será removido: ');
    sintReadLn(deletaDir);

    WritePipeOut(InputPipeWrite, ('rmdir ' + deletaDir + #$0a));
    response := getPipedData;

    if pos('OK', response) <> 0 then
        begin
            sintWrite('Diretório deletado com sucesso.');
            Result := true;
        end
    else
        begin
            WritePipeOut(InputPipeWrite, ('ls ' + deletaDir + #$0a));

            if pos('Unable to open', getPipedData) <> 0 then
                sintWriteLn('Diretório com o nome ' + deletaDir + ' não existe.')
            else
                begin
                    sintWrite('O diretório ' + deletaDir + ' possui arquivos nele. Deseja realmente excluir?');
                    c := popupMenuPorLetra('SN');

                    if UpperCase(c) = 'S' then
                        begin
                            WritePipeOut(InputPipeWrite, ('rm ' + deletaDir + '/*' + #$0a));
                            WritePipeOut(InputPipeWrite, ('rmdir ' + deletaDir + '/*' + #$0a));
                            WritePipeOut(InputPipeWrite, ('rmdir ' + deletaDir + #$0a));
                            if pos('OK', getPipedData) <> 0 then
                                begin
                                    sintWrite('Diretório deletado com sucesso.');
                                    Result := true;
                                end;
                        end
                end;
            ERRO := ERRO_CONEXAO;
        end;
end;

function renomearDir: Boolean;
var
    response, renomearDir, dir: string;
begin
    Result := false;

    sintWriteLn('Informe o nome do diretório que deseja renomear: ');
    sintReadLn(dir);

    sintWriteLn('Informe o novo nome: ');
    sintReadLn(renomearDir);

    WritePipeOut(InputPipeWrite, ('ren ' + dir + ' ' + renomearDir + #$0a));
    response := getPipedData;

    if pos('->', response) <> 0 then
        begin
            sintWrite('Diretório renomeado com sucesso.');
            Result := true;
        end
    else
        begin
            ERRO := ERRO_CONEXAO;
            sintWriteLn('Diretório com o nome ' + dir + ' não existe');
        end;
end;

function moverDir: Boolean;
var
    response, moverDir, dir: string;
begin
    Result := false;

    sintWriteLn('Informe o nome do diretório que deseja mover: ');
    sintReadLn(moverDir);
    WritePipeOut(InputPipeWrite, ('ls ' + moverDir + #$0a));
    if pos('Unable to open', getPipedData) <> 0 then
        begin
            sintWriteLn('O diretório a ser movido ' + moverDir + ' não existe na pasta atual.');
            exit;
        end;

    sintWriteLn('Informe o nome da pasta de destino: ');
    sintReadLn(dir);
    WritePipeOut(InputPipeWrite, ('ls ' + dir + #$0a));
    if pos('Unable to open', getPipedData) <> 0 then
        begin
            sintWriteLn('O diretório destino ' + dir + ' não existe na pasta atual.');
            exit;
        end;

    WritePipeOut(InputPipeWrite, ('ren ' + moverDir + ' ' + dir + #$0a));
    response := getPipedData;

    if pos('->', response) <> 0 then
        begin
            sintWrite('Diretório movido com sucesso.');
            Result := true;
        end
    else
        ERRO := ERRO_CONEXAO;
end;

function renomearArq(nomeArq: string): Boolean;
var
    response, renomeaArq: string;
begin
    Result := false;

    sintWriteLn('Informe o novo nome do arquivo: ');
    sintReadLn(renomeaArq);
    //renomeaArq := rotaAtual + '/' + renomeaArq;

    WritePipeOut(InputPipeWrite, ('mv ' + nomeArq + ' ' + renomeaArq + #$0a));
    response := getPipedData;

    if pos('->', response) <> 0 then
        begin
            sintWrite('Arquivo renomeado com sucesso.');
            Result := true;
        end
    else
        ERRO := ERRO_CONEXAO;
end;

function deletarArq(nomeArq: string): Boolean;
var
    response: string;
    c: char;
begin
    Result := false;

    sintWriteLn('Deseja realmente remover o arquivo?');
    c := popupMenuPorLetra('SN');

    if UpperCase(c) = 'S' then
        begin
            WritePipeOut(InputPipeWrite, ('rm ' + nomeArq + #$0a));
            response := getPipedData;

            if pos('OK', response) <> 0 then
                begin
                    sintWrite('Arquivo removido com sucesso.');
                    Result := true;
                end
            else
                ERRO := ERRO_CONEXAO;
        end;
end;

function propriedadesArq(nomeArq: string): Boolean;
var
    response, aux, item: string;
    List: TStringList;
    i, p: integer;
begin
    Result := false;

    WritePipeOut(InputPipeWrite, ('ls ' + '*' + nomeArq + #$0a));
    response := getPipedData;

    if pos('Listing directory', response) <> 0 then
        begin
            List := TStringList.Create;

            ExtractStrings([#$D, #$A], [], PChar(response), List);
            if List.Count = 1 then
                begin
                    ERRO := ERRO_NEXISDIR;
                    Result := false;
                    exit;
                end;

            for i := 0 to List.Count-1 do
                if pos(nomeArq, List[i]) <> 0 then
                    begin
                        aux := extrairDados(List[i]);

                        p := Pos('dir|', aux);
                        if p <> 0 then
                            delete(aux, 1, p+3);

                        p := Pos('|', aux);
                        item := copy(aux, 1, p-1);
                        sintWriteLn('Tamanho arquivo(em MB): ' + IntToStr(round(pegaReal(item)/1000000)));
                        delete(aux, 1, p);

                        p := pos('|', aux);
                        item := copy(aux, 1, p-1);
                        sintWriteLn('Última modificação: ' + formatarDataPT(item));
                    end
        end;
end;

procedure opcoesArqFTP(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
begin
    tabLetrasOpcao := 'BELRDPT' + ESC;

    listaOpcoes.Add('B - Baixar Arquivo');
    listaOpcoes.Add('E - Editar Remotamente Arquivo');
    listaOpcoes.Add('L - Baixar Arquivo e editar');
    listaOpcoes.Add('R - Renomear Arquivo');
    listaOpcoes.Add('D - Deletar Arquivo');
    listaOpcoes.Add('P - Propriedades Arquivo');
    listaOpcoes.Add('T - Terminar');
end;

procedure opcoesDirFTP(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
begin
    tabLetrasOpcao := 'ECRMDFT' + ESC;

    listaOpcoes.Add('E - Enviar arquivo na pasta atual');
    listaOpcoes.Add('C - Criar pasta no diretório atual');
    listaOpcoes.Add('R - Renomear pasta do diretório atual');
    listaOpcoes.Add('M - Mover pasta do diretório atual');
    listaOpcoes.Add('D - Deletar pasta do diretório atual');
    listaOpcoes.Add('F - Falar caminho diretório atual');
    listaOpcoes.Add('T - Terminar');
end;

function executaOpcaoFTP(opcao: string; out prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;
begin
    Result := true;

    if tipoDado = Arquivo then nomeArqConectado := nomeArq;

    if tipoDado = Arquivo then
        if opcao = 'B' then
            begin
                editarRemotamente := false;
                if not baixarArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'E' then
            begin
                editarRemotamente := true;
                if EditarArq(nomeArq) then
                    prosseguir := false;
            end
        else
        if opcao = 'L' then
            begin
                editarRemotamente := false;
                if EditarArq(nomeArq) then
                    prosseguir := false;
            end
        else
        if opcao = 'R' then
            begin
                if renomearArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'D' then
            begin
                if deletarArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'P' then
            begin
                if propriedadesArq(nomeArq) then
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
        if opcao = 'E' then
            begin
                if not enviarArq then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'C' then
            begin
                if not criarDir then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'M' then
            begin
                if not moverDir then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'R' then
            begin
                if not renomearDir then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'D' then
            begin
                if not removerDir then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'F' then
            begin
                sintWriteLn(rotaAtual);
                prosseguir := true;
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

procedure _assignFileFTP(var arq: TextFile; nomeArq: string);
begin
    if editarRemotamente then
        AssignFile(arq, '$$$temp$$$.txt')
    else
        AssignFile(arq, nomeArq);
end;

function _ioresultFTP: Integer;
begin
    Result := 0;

    if tipoDeErro <> 'ND' then
        Result := 1;
end;

procedure _closeFileFTP(var FileHandle: TextFile);
var
    response, dir: string;
    c: Char;
    p: integer;
begin
     Delay(300);
     if editarRemotamente then
         begin
             WritePipeOut(InputPipeWrite, 'lcd ' + GetCurrentDir + #$0a);
             response := getPipedData;

             WritePipeOut(InputPipeWrite, 'put ' + '$$$temp$$$.txt ' + nomeArqConectado + #$0a);
             response := getPipedData;
             if pos('remote', response) <> 0 then
                 begin
                     sintWrite('Arquivo gravado remotamente.');
                     DeleteFile('$$$temp$$$.txt');
                 end
             else
                 ERRO := ERRO_NEXISARQ;
         end
     else
         begin
             mensagem('EPBAIXA', 0); {Deseja baixar no diretório atual? }
             c := popupMenuPorLetra('SN');

             if c = ESC then exit;

             if UpperCase(c) = 'N' then
                 begin
                     dir := selPreferidos;
                     if (dir = '') and (dir = ESC) then
                         exit;

                     tituloJanela('baixando ' + nomeArqConectado);

                     if FileExists(dir + '\' + nomeArqConectado) then
                         begin
                             sintWriteLn('Arquivo já existe no diretório ' + dir);
                             sintWrite('Deseja substituir? ');

                             if popupMenuPorLetra('SN') = 'S' then
                                 DeleteFile(dir + '\' + nomeArqConectado)
                             else
                                 exit;
                         end;

                     MoveFile(PChar(nomeArqConectado), PChar(dir + '\' + nomeArqConectado));
                     DeleteFile(nomeArqConectado);
                 end;
         end;
end;

function downloadFileFTP(nomeArqBaixar, dir: string): Boolean;
var response, temporarioArq: string;
begin
    Result := false;
    temporarioArq := '';

    if dir = '' then dir := GetCurrentDir;
    WritePipeOut(InputPipeWrite, 'lcd ' + dir + #$0a);
    response := getPipedData;

    if editarRemotamente then
        begin
            temporarioArq := '$$$temp$$$.txt'
        end
    else
        begin
            if FileExists(dir + '\' + nomeArqBaixar) then
                begin
                    sintWriteLn('Arquivo já existe no diretório ' + dir);
                    sintWrite('Deseja substituir? ');

                    if popupMenuPorLetra('SN') = 'S' then
                        DeleteFile(dir + '\' + nomeArqBaixar)
                    else
                        exit;
                end;
        end;

    if pos('New local directory', response) <> 0 then
        begin
            WritePipeOut(InputPipeWrite, 'get ' + nomeArqBaixar + ' ' + temporarioArq + #$0a);
            response := getPipedData;

            if pos('local', response) <> 0 then
                Result := true
            else
                ERRO := ERRO_NEXISARQ;
        end;
end;

procedure _resetFTP (var FileHandle: TextFile);
var
  nomeRota, response: string;
  p: integer;
begin
    if not downloadFileFTP(nomeArqConectado, '') then
        exit;

    Reset(FileHandle);
end;

procedure inicializaFTP(ponte: TPonte; nomePonte: string);
begin
    ponteConectadaFTP := ponte;

    if not createRotaFTP(nomePonte) then
        begin
            ERRO := ERRO_CONEXAO;
            exit;
        end;

    if not ContaESenha(ponte) then
        begin
            ERRO := ERRO_CONEXAO;
            exit;
        end;
    sintetiza('ponte FTP conectada.');
end;

procedure fechaFTP;
begin
    rotaAtual := '';
    progStop;
end;

end.
