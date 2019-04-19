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
  epPipe,
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
function listarArqScript(out listar: TStringList): Boolean;

{ funções e procedures para manipulação de arquivos }
function opcoesArqScripVox(listaOpcoes: TStringList;  var tabLetrasOpcao: string): Boolean;
function downloadFileScriptVox(nomeArqBaixar, dir: string): Boolean;
function _FileExistsScripVox(fileName: string): Boolean;
function _findFirstScripVox(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec; listar: TStringList): integer;
function _findNextScripVox(var SearchResults: TSearchRec; listar: TStringList): integer;
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
    rotaAtual, tipoScript, nomeArqConectado: string;
    ponteConectadaScript: TPonte;

{----------------------------------------------------------------------}
{       Cria caminho de rota de acordo com servidor ScriptVox          }
{----------------------------------------------------------------------}

function createRotaScriptVox(caminho: string): Boolean;
var
    p: integer;
begin
    Result := false;
    p := pos('@', caminho);

    if tipoScript = 'DROPBOX' then
        begin
            rotaAtual := '/';
            if p <> 0 then
                rotaAtual := rotaAtual + copy(caminho, p-1, Length(caminho)+1);

            Result := true;
        end
end;

{----------------------------------------------------------------------}
{             Captura propriedades de um arquivo ou pasta              }
{----------------------------------------------------------------------}

procedure propriedadesArq (nomeArq: string);
var
    response, aux: string;
    p: integer;
begin
    if tipoScript='DROPBOX' then
        begin
            WritePipeOut(InputPipeWrite, 'PROPRIEDADE' + #$0a);
            WritePipeOut(InputPipeWrite, rotaAtual + nomeArq + #$0a);

            response := getPipedData;

            if (pos('404', response) = 0) or
               (pos('405', response) = 0) or
               (pos('401', response) = 0) or
               (pos('403', response) = 0) or
               (pos('500', response) = 0) then
                begin
                    while response <> #$D#$A do
                        begin
                            p := pos('|', response);
                            aux := copy (response, 1, p-1);
                            sintWriteLn(aux);
                            delete (response, 1, p);
                        end;
                end;

        end;
end;

function downloadFileScriptVox(nomeArqBaixar, dir: string): Boolean;
var
    response, rotaRemota: string;
begin
    Result := false;
    
    if dir = '' then
        dir := GetCurrentDir;

    if FileExists(dir + '\' + nomeArqBaixar) then
        begin
            sintWriteLn('Arquivo já existe no diretório ' + dir);
            sintWrite('Deseja substituir? ');

            if popupMenuPorLetra('SN') = 'S' then
                DeleteFile(dir + '\' + nomeArqBaixar)
            else
                exit;
        end;

    if rotaAtual = '/' then
        rotaRemota := rotaAtual + nomeArqBaixar
    else
        rotaRemota := rotaAtual + '/' + nomeArqBaixar;

    WritePipeOut(InputPipeWrite, 'BAIXAR' + #$0a);
    WritePipeOut(InputPipeWrite, dir + #$0a);
    WritePipeOut(InputPipeWrite, rotaRemota + #$0a);
    response := getPipedData;

    if pos('200', response) <> 0 then
        Result := true;

end;

{----------------------------------------------------------------------}
{            Ver o tipo do serviço e envia para o respectivo           }
{            script para verificar se existe o diretório               }
{----------------------------------------------------------------------}

function _directoryexistScripVox: Boolean;
begin
    if tipoScript = 'DROPBOX' then
        begin
            WritePipeOut(InputPipeWrite, 'PROPRIEDADE' + #$0a);
            WritePipeOut(InputPipeWrite, rotaAtual + #$0a);
        end;
end;

{----------------------------------------------------------------------}
{            Ver o tipo do serviço e envia para o respectivo           }
{            script para verificar se existe o arquivo                 }
{----------------------------------------------------------------------}

function _FileExistsScripVox(fileName: string): Boolean;
var
    rota, response: string;
begin
    Result := false;

    if rotaAtual = '/' then
        rota := rotaAtual + fileName
    else
        rota := rotaAtual + '/' + fileName;

    if tipoScript = 'DROPBOX' then
        begin
            WritePipeOut(InputPipeWrite, 'PROPRIEDADE' + #$0a);
            response := WritePipeOut(InputPipeWrite, rota + #$0a);
            response := getPipedData;

            if response <> '' then
                Result := true;
        end;
end;

{----------------------------------------------------------------------}
{           Retorna valor do response da busca pela conta              }
{----------------------------------------------------------------------}

function listarArqScript(out listar: TStringList): Boolean;
var
    response, item: string;
    i, p: integer;
begin
    Result := true;

    WritePipeOut(InputPipeWrite, 'LISTAR' + #$0a);
    if rotaAtual = '/' then
        WritePipeOut(InputPipeWrite, 'raiz' + #$0a)
    else
        WritePipeOut(InputPipeWrite, rotaAtual + #$0a);

    response := getPipedData;

    if response <> '' then
        begin
            listar.Add('..');
            while response <> '' do
                begin
                    p := Pos(''#$D#$A'', response);
                    item := copy(response, 1, p-1);
                    listar.Add(item);
                    delete(response, 1, p+1);
                end;
        end;
end;


{----------------------------------------------------------------------}
{              função findFirst para protocolo scriptVox               }
{----------------------------------------------------------------------}

function _findFirstScripVox(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec; listar: TStringList): integer;
var
   item: string;
   lengthDir: integer;
begin
    ponteiro_prox := 0;
    lengthDir := listar.Count;

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
            item := listar[ponteiro_prox];
            SearchResult.Name := item;
            StrPCopy(SearchResult.FindData.cFileName, item);
        end;
    Result := 0;
end;

function _findNextScripVox(var SearchResults: TSearchRec; listar: TStringList): integer;
var
   item: string;
begin
    if ponteiro_prox = listar.Count then
        Result := 1
    else
        begin
            item := listar[ponteiro_prox];
            SearchResults.Name := item;
            StrPCopy(SearchResults.FindData.cFileName, item);

            Result := 0;
        end;
end;

procedure _ChDirScripVox(Dir: string);
begin
    if ponteConectadaScript.Tipo = 'DROPBOX' then
        begin
            if rotaAtual = '/' then
                rotaAtual := rotaAtual + Dir
            else
                rotaAtual := rotaAtual + '/' + Dir;
        end;
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

            p := Pos('/', copyRota);
            while p <> 0 do
                begin
                    delete(copyRota, 1, p);
                    p := Pos('/', copyRota);
                end;

            p := length(rotaAtual) - length(copyRota) - 1;
            rotaAtual := copy(rotaAtual, 1, p);

            if rotaAtual <> '' then
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
    rotaLocal, nomeArq, response: string;
    p: integer;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            sintWriteLn('Informe o nome do arquivo: ');
            sintReadLn(nomeArq);
            sintWriteLn('Informe onde o arquivo se encontra (rota): ');
            sintReadLn(rotaLocal);

            WritePipeOut(InputPipeWrite, 'ENVIAR' + #$0a);
            WritePipeOut(InputPipeWrite, nomeArq + #$0a);
            WritePipeOut(InputPipeWrite, rotaLocal + #$0a);
            WritePipeOut(InputPipeWrite, rotaAtual + #$0a);

            response := getPipedData;

            if pos('200', response) <> 0 then
                Result := true;
        end;
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
var
    c: char;
    rotaRemota, response: string;
begin
   Result := false;

   if rotaAtual = '/' then
        rotaRemota := rotaAtual + nomeArq
    else
        rotaRemota := rotaAtual + '/' + nomeArq;

   if tipoScript = 'DROPBOX' then
       begin
            sintWrite('Deseja realmente remover o arquivo?');
            c := popupMenuPorLetra('SN');

            if UpperCase(c) = 'S' then
                begin
                    WritePipeOut(InputPipeWrite, 'EXCLUIR' + #$0a);
                    WritePipeOut(InputPipeWrite, rotaRemota + #$0a);

                    response := getPipedData;

                    if pos('200', response) <> 0 then
                        Result := true;
                end;
       end
end;

function renomearArq(nomeArq: string): Boolean;
var
    novoNome, novaRota, velhaRota, response: string;
begin
    Result := false;

    if tipoScript = 'DROPBOX' then
        begin
            sintWriteLn('Informe o novo nome: ');
            sintReadLn(novoNome);

            if _FileExistsScripVox(nomeArq) then
                begin
                    if rotaAtual = '/' then
                        begin
                            velhaRota := rotaAtual + nomeArq;
                            novaRota := rotaAtual + novoNome;
                        end
                    else
                        begin
                            velhaRota := rotaAtual + '/' + nomeArq;
                            novaRota := rotaAtual + '/' + novoNome;
                        end;

                    WritePipeOut(InputPipeWrite, 'RENOMEAR' + #$0a);
                    WritePipeOut(InputPipeWrite, velhaRota + #$0a);
                    WritePipeOut(InputPipeWrite, novaRota + #$0a);

                    response := getPipedData;

                    if pos('200', response) <> 0 then
                        Result := true;
                end
            else
                sintWriteLn('Arquivo ' + nomeArq + ' não existe.');
        end
end;

function opcoesArqScripVox(listaOpcoes: TStringList;  var tabLetrasOpcao: string): Boolean;
begin
    Result := true;
    tabLetrasOpcao := 'EBDRPT' + ESC;

    if tipoScript = 'DROPBOX' then
        begin
            listaOpcoes.Add('E - Editar Arquivo');
            listaOpcoes.Add('B - Baixar Arquivo');
            listaOpcoes.Add('D - Deletar Arquivo');
            listaOpcoes.Add('R - Renomear Arquivo');
            listaOpcoes.Add('P - Propriedades');
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
            listaOpcoes.Add('C - Enviar arquivo para dropbox');
            listaOpcoes.Add('P - Criar pasta');
            listaOpcoes.Add('R - Remover pasta');
            listaOpcoes.Add('T - Terminar');
        end
end;

function executaOpcaoScripVox(opcao: string; out prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;
begin
    Result := false;

    if tipoDado = Arquivo then nomeArqConectado := nomeArq;

    if tipoDado = Arquivo then
        if opcao = 'E' then
           begin
               if EditarArq(nomeArq) then
                    prosseguir := false;
           end
        else
        if opcao = 'B' then
            begin
                if not baixarArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'D' then
            begin
                if not deletaArq(nomeArq) then
                    Result := false;
                prosseguir := false;
            end
        else
        if opcao = 'P' then
            begin
            propriedadesArq (nomeArq);
            prosseguir := false;
            end
        else
        if opcao = 'R' then
            begin
                if not renomearArq(nomeArq) then
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
var
    response: String;
begin

    if tipoScript = 'DROPBOX' then
        begin
            WritePipeOut(InputPipeWrite, 'ENVIAR' + #$0a);
            WritePipeOut(InputPipeWrite, nomeArqConectado + #$0a);
            WritePipeOut(InputPipeWrite, GetCurrentDir + #$0a);
            WritePipeOut(InputPipeWrite, rotaAtual + #$0a);

            response := getPipedData;

            if pos('200', response) <> 0 then
                DeleteFile(nomeArqConectado);
        end;
end;

procedure _resetScripVox(var FileHandle: TextFile);
var
    rotaLocal, rotaRemota, response: String;
begin
    if rotaAtual = '/' then
        rotaRemota := rotaAtual + nomeArqConectado
    else
        rotaRemota := rotaAtual + '/' + nomeArqConectado;

    rotaLocal := GetCurrentDir + '\' + nomeArqConectado;

    if tipoScript = 'DROPBOX' then
        begin
            WritePipeOut(InputPipeWrite, 'BAIXAR' + #$0a);
            WritePipeOut(InputPipeWrite, rotaLocal + #$0a);
            WritePipeOut(InputPipeWrite, rotaRemota + #$0a);

            response := getPipedData;

            if pos('200', response) = 0 then
                ERRO := ERRO_ACESSTERM;
        end;
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

            if not executarAcesso('.\pyApis\dbxPonte.exe') then
                begin
                    ERRO := ERRO_CONEXAO;
                    progStop;
                    exit;
                end;

            WritePipeOut(InputPipeWrite, 'login' + #$0a);
            response := getPipedData;

            if Pos('200', response) = 0 then
                begin
                    progStop;
                    Exit;
                end;
            sintetiza('ponte '+ ponte.Tipo + ' conectada.');
        end
    else
        Result := false;
end;

procedure fechaScriptVox;
begin
    if tipoScript = 'DROPBOX' then
        begin
            rotaAtual := '';
            progStop;
        end;
end;
end.
