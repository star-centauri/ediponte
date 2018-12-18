unit dvPonte;

interface
uses
  dvcrt,
  dvwin,
  dvform,
  dvinet,
  dvssl,
  dvHTTP,
  dvFTP,
  dvScriptVox,
  minireg,
  epError,
  epvars,
  classes,
  synacode,
  windows,
  sysUtils,
  strUtils;


{ rotinas do dvPonte }
function inicializaPonteSelecionada(nomePonte: string): Boolean;
procedure fecharPonte;
function opcoesDirProtocolos(out listaOpcoes: TStringList; var tabLetrasOpcao: string): Boolean;
procedure folhear(var n: integer);
function downloadFile (dir, nomeArqBaixar: string): boolean;
function ponteFoiCriada(nomeRotaDig: string): boolean;
function voltarDir: boolean;
function buscaSel(n: integer): string;
procedure inicPonte;
procedure closePonte;
function salvaDadosPonte(nomePonte: string): boolean;
function opcoesArqProtocolos(out listaOpcoes: TStringList; var tabLetrasOpcao: string): Boolean;
function executaOpcaoProtocol(opcao: string; var prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;

{ SubRotinas relacionada com processos de arquivo/diretório nativos do Delphi }
function _findFirst(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec): integer;
function _findNext (var SearchResults: TSearchRec): integer;
function _setCurrentDir (Dir: string ): Boolean;
function _deleteFile (FileName: string): Boolean;
function _fileExists (FileName: string): Boolean;
function _directoryexists (DirectoryName: string ): Boolean;
procedure _ChDir (Dir: string);
procedure _findClose ( var SearchResults: TSearchRec );
procedure _assignFile (var arq: TextFile; nomeArq: string);
procedure _getdir (Drive: Byte; var Dir: string );
procedure _reset (var FileHandle: TextFile);
function _ioresult: Integer;
function _eof(var FileHandle: TextFile): Boolean;
procedure _closeFile(var FileHandle: TextFile);

implementation
uses
    dvArq2;

var
  arqIniPontes: string;
  rotaPonte: boolean;
  listar: TStringList;
  statusUltIO: integer;
  ponteConectada: TPonte;


function criarRota(caminho: string): Boolean;
begin
     Result := false;
     
     if ponteConectada.Tipo = 'WEB' then
         Result := createRotaHTTP(caminho)
     else
     if ponteConectada.Tipo = 'FTP' then
         Result := createRotaFTP(caminho)
     else
         Result := createRotaScriptVox(caminho);
end;

{----------------------------------------------------------------------}
{               Quarda os dados da ponte conectada                     }
{----------------------------------------------------------------------}

function salvaDadosPonte(nomePonte: string): boolean;
var
    p: integer;
    ponte: string;
begin
    Result := false;
    p := Pos('@', nomePonte);

    if p <> 0 then
        ponte := copy(nomePonte, 1, p-1)
    else
        ponte := nomePonte;

    {recebendo valores}
    ponteConectada.Nome := sintAmbienteArq(ponte, 'Nome', '', arqIniPontes);
    ponteConectada.Tipo := sintAmbienteArq(ponte, 'Tipo', '', arqIniPontes);
    ponteConectada.Servidor := sintAmbienteArq(ponte, 'Servidor', '', arqIniPontes);
    ponteConectada.Porta := StrToInt(sintAmbienteArq(ponte, 'Porta', '', arqIniPontes));
    ponteConectada.Conta := sintAmbienteArq(ponte, 'Conta', '', arqIniPontes);
    ponteConectada.Senha := sintAmbienteArq(ponte, 'Senha', '', arqIniPontes);

    {Validação}
    if (ponteConectada.Nome <> '') and
       (ponteConectada.Tipo <> '') and
       (ponteConectada.Servidor <> '') and
       (ponteConectada.Porta <> 0) and
       (ponteConectada.Conta <> '') then
          result := true;
end;

{----------------------------------------------------------------------}
{                folhear ponte que estão disponiveis                   }
{----------------------------------------------------------------------}

procedure folhear(var n: integer);
var
    sl : TStringList;
    i: integer;
    s, servidorPonte: string;

begin
    textBackground (BLUE);
    sl := sintItensAmbienteArq ('', arqIniPontes);

    popupMenuCria (wherex, wherey, 40, sl.count, blue);
    for i := 0 to sl.count-1 do
        begin
            s := sintAmbienteArq (sl[i], 'Nome', '', arqIniPontes);
            popupmenuadiciona('', s);
        end;

    n := popupMenuSeleciona;

    if n > 0 then
        begin
            if not salvaDadosPonte(sl[n-1]) then
                ERRO := ERRO_PTINCORRETA;
        end;

    TextBackground(Black);
    limpaBaixo(WhereY);
    sl.free;
end;

{----------------------------------------------------------------------}
{                      buscar Arquivo Selecionado                      }
{----------------------------------------------------------------------}

function buscaSel(n: integer): string;
var
    p, i: integer;
    aux, item, ehDir: string;
    list: TList;
begin
    if ponteConectada.Tipo = 'WEB' then
        begin
            aux := listar[n];
            ehDir := '';

            //Pegar nome
            p := Pos('|', aux);
            item := copy(aux, 1, p-1);
            p := Pos('/', item);
            if p <> 0 then ehDir := ' Diretório';
            Result := item + ehDir;
        end
    else
    if ponteConectada.Tipo = 'FTP' then
       begin
           aux := listar[n+1];
           ehDir := '';
           p := pos('dir', aux);
           if p <> 0 then
               begin
                   ehDir := ' Diretório';
                   delete(aux, 1, p+3);
               end;

            p := Pos('|', aux);
            delete(aux, 1, p+1);

            p := Pos('|', aux);
            item := copy(aux, p+1, Length(aux));
            if item <> '..' then item := item + ehDir;
            Result := item;
       end
    else
    if ponteConectada.Tipo = 'DROPBOX' then
        begin
            list := obtemListArq;
            Result := PMySearchRec(list[n]).sr.FindData.cFileName;
        end;
end;

{ --------------------------------------------------------------------------------- }

procedure listarArq();
begin
     listar.Clear;

     if ponteConectada.Tipo = 'WEB' then
         listarArqHTTP(listar)
     else
     if ponteConectada.Tipo = 'FTP' then
         listarArqFTP(listar);
end;

{ --------------------------------------------------------------------------------- }

function _findFirst(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec): integer;
begin
    if rotaPonte then
        begin
            listar := TStringList.Create;
            listar.Clear;
            listarArq;

            if ponteConectada.Tipo = 'WEB' then
                Result := _findFirstHTTP(FileMask, Attributes, SearchResult, listar)
            else
            if ponteConectada.Tipo = 'FTP' then
                Result := _findFirstFTP(FileMask, Attributes, SearchResult, listar)
            else
                Result := _findFirstScripVox(FileMask, Attributes, SearchResult);
        end
    else
        Result := FindFirst(FileMask, Attributes, SearchResult);
end;

{ --------------------------------------------------------------------------------- }

function _findNext(var SearchResults: TSearchRec): integer;
begin
    if rotaPonte then
        begin
            ponteiro_prox := ponteiro_prox + 1;

            if ponteConectada.Tipo = 'WEB' then
                Result := _findNextHTTP(SearchResults, listar)
            else
            if ponteConectada.Tipo = 'FTP' then
                Result := _findNextFTP(SearchResults, listar)
            else
                Result := _findNextScripVox(SearchResults);
        end
    else
       Result := FindNext(SearchResults)
end;

{ --------------------------------------------------------------------------------- }

procedure _findClose ( var SearchResults: TSearchRec );
begin
    findClose(SearchResults);
end;

{ --------------------------------------------------------------------------------- }

function _setCurrentDir (Dir: string ) : Boolean;
var
  ehPonte: integer;
  arq: string;
begin
    Result := false;

    if rotaPonte then
        begin
            if ponteConectada.Tipo = 'WEB' then
                Result := createRotaHTTP(Dir)
            else
            if ponteConectada.Tipo = 'FTP' then
                Result := createRotaFTP(Dir)
            else
                Result := createRotaScriptVox(Dir);
        end
    else
        Result := SetCurrentDir(Dir);
end;

{ --------------------------------------------------------------------------------- }

procedure _ChDir(Dir: string);
var
  nome, arq: string;
begin
    if Dir = '' then exit;

    if rotaPonte then
        begin
           if ponteConectada.Tipo = 'WEB' then
                _ChDirHTTP(Dir)
            else
            if ponteConectada.Tipo = 'FTP' then
                _ChDirFTP(Dir)
            else
                _ChDirScripVox(Dir);
        end
    else
       ChDir(Dir);
end;

{ --------------------------------------------------------------------------------- }

procedure _assignFile (var arq: TextFile; nomeArq: string);
var
  nomeRota: string;
  p: integer;
begin
    if rotaPonte then
        if ponteConectada.Tipo = 'WEB' then
            _assignFileHTTP(arq, nomeArq)
        else
        if ponteConectada.Tipo = 'FTP' then
            _assignFileFTP(arq, nomeArq)
        else
            _assignFileScripVox(arq, nomeArq)
    else
        AssignFile(arq, nomeArq);
end;

{ --------------------------------------------------------------------------------- }

function _deleteFile (FileName: string): Boolean;
begin
    DeleteFile(FileName);
end;

{ --------------------------------------------------------------------------------- }

procedure _getdir (Drive: Byte; var Dir: string);
begin
    getdir(Drive, Dir);
end;

{ --------------------------------------------------------------------------------- }

function _fileExists (FileName: string): Boolean;
var
    nomeRota: string;
    p, soquete: integer;
    pbuf: PbufRede;
begin
    Result := false;

    if rotaPonte then
        begin
            if ponteConectada.Tipo = 'WEB' then
                Result := _FileExistsHTTP
            else
            if ponteConectada.Tipo = 'FTP' then
                Result := _FileExistsFTP(FileName)
            else
                Result := _FileExistsScripVox(FileName);
        end
    else
        Result := FileExists(FileName);
end;

{ --------------------------------------------------------------------------------- }

function _directoryexists (DirectoryName: string ): Boolean;
begin
    Result := false;

    if rotaPonte then
        begin
            if ponteConectada.Tipo = 'WEB' then
                Result := _directoryExistHTTP
            else
            if ponteConectada.Tipo = 'FTP' then
                Result := _directoryExistFTP
            else
                Result := _directoryexistScripVox;
        end
    else
        Result := DirectoryExists(DirectoryName);
end;

{ --------------------------------------------------------------------------------- }

procedure inicPonte;
begin
   rotaPonte := true;
end;

{------------------------------------------------------------------------------------}

procedure closePonte;
begin
    rotaPonte := false;
end;

{----------------------------------------------------------------------}
{                Ver se ponte foi criada no pontes.ini                 }
{----------------------------------------------------------------------}

function ponteFoiCriada(nomeRotaDig: string): boolean;
var
   p: integer;
   opcao: Char;
begin
    Result := false;
    p := Pos('@', nomeRotaDig);

    if p = 0 then
        ERRO := ERRO_DIG
    else
        begin
            if sintambientearq(copy(nomeRotaDig, 1, p-1), 'Nome', '', arqIniPontes) <> '' then
                Result := true
            else
                ERRO := ERRO_PNC;
        end;
end;

{----------------------------------------------------------------------}
{                  Função para voltar diretórios                       }
{----------------------------------------------------------------------}

function voltarDir: boolean;
begin
    Result := false;

    if ponteConectada.Tipo = 'WEB' then
        Result := voltarDirHTTP
    else
    if ponteConectada.Tipo = 'FTP' then
        Result := voltarDirFTP
    else
        Result := voltarDirScripVox;
end;

{----------------------------------------------------------------------}
{          procedure que cria a lista de opções de manipular           }
{             arquivos em relação a cada protocolo                     }
{----------------------------------------------------------------------}

function opcoesArqProtocolos(out listaOpcoes: TStringList; var tabLetrasOpcao: string): Boolean;
begin
    Result := true;

    if ponteConectada.Tipo = 'WEB' then
        opcoesArqHTTP(listaOpcoes, tabLetrasOpcao)
    else
    if ponteConectada.Tipo = 'FTP' then
        opcoesArqFTP(listaOpcoes, tabLetrasOpcao)
    else
        Result := opcoesArqScripVox(listaOpcoes, tabLetrasOpcao);
end;

function opcoesDirProtocolos(out listaOpcoes: TStringList; var tabLetrasOpcao: string): Boolean;
begin
    Result := false;

    if ponteConectada.Tipo = 'FTP' then
        begin
            opcoesDirFTP(listaOpcoes, tabLetrasOpcao);
            Result := true;
        end
    else
    if ponteConectada.Tipo = 'DROPBOX' then
        begin
            opcoesDirScriptVox(listaOpcoes, tabLetrasOpcao);
            Result := true;
        end;

end;

function executaOpcaoProtocol(opcao: string; var prosseguir: boolean; nomeArq: string; tipoDado: DataType): Boolean;
begin
    Result :=  false;

    if ponteConectada.Tipo = 'WEB' then
        Result := executaOpcaoHTTP(opcao, prosseguir, nomeArq)
    else
    if ponteConectada.Tipo = 'FTP' then
        Result := executaOpcaoFTP(opcao, prosseguir, nomeArq, tipoDado)
    else
        Result := executaOpcaoScripVox(opcao, prosseguir, nomeArq, tipoDado);
end;

function downloadFile (dir, nomeArqBaixar: string): boolean;
begin
    Result := false;

    if ponteConectada.Tipo = 'WEB' then
        Result := downloadFileHTTP(nomeArqBaixar, dir)
    else
    if ponteConectada.Tipo = 'FTP' then
        Result := downloadFileFTP(nomeArqBaixar, dir)
    else
        //Result := executaOpcaoScripVox(opcao, prosseguir);
end;

procedure _reset (var FileHandle: TextFile);
begin
    if rotaPonte then
        if ponteConectada.Tipo = 'WEB' then
            _resetHTTP(FileHandle)
        else
        if ponteConectada.Tipo = 'FTP' then
            _resetFTP(FileHandle)
        else
            _resetScripVox(FileHandle)
    else
        Reset(FileHandle);
end;

function _ioresult: Integer;
begin
    Result := 0;
    
    if rotaPonte then
        if ponteConectada.Tipo = 'WEB' then
            Result := _ioresultHTTP
        else
        if ponteConectada.Tipo = 'FTP' then
            Result := _ioresultFTP
        else
            Result := _ioresultScripVox(ponteConectada)
    else
        Result := IOResult;
end;

function _eof(var FileHandle: TextFile): Boolean;
begin
    Result := eof(FileHandle);
end;

procedure _closeFile(var FileHandle: TextFile);
begin
    if rotaPonte then
        if ponteConectada.Tipo = 'WEB' then
            _closeFileHTTP(FileHandle)
        else
        if ponteConectada.Tipo = 'FTP' then
            _closeFileFTP(FileHandle)
        else
            _closeFileScripVox(FileHandle)
    else
        CloseFile(FileHandle);
end;

function inicializaPonteSelecionada(nomePonte: string): Boolean;
var
    protocolo: string;
begin
    Result := false;

    if rotaPonte then
        begin
            protocolo := ponteConectada.Tipo;

            if AnsiUpperCase(protocolo) = 'WEB' then
                inicializaHTTP(ponteConectada, nomePonte)
            else
            if AnsiUpperCase(protocolo) = 'FTP' then
                inicializaFTP(ponteConectada, nomePonte)
            else
                Result := inicializaScriptVox(ponteConectada, nomePonte);

            if tipoDeErro <> ERRO_CONEXAO then
                Result := true;
        end
end;

procedure fecharPonte;
begin
    if rotaPonte then
        begin
            if ponteConectada.Tipo = 'WEB' then
                fechaHTTP
            else
            if ponteConectada.Tipo = 'FTP' then
                fechaFTP
            else
                fechaScriptVox;
        end
end;

initialization
    arqIniPontes := sintAmbiente('PONTEVOX', 'ARQPONTES');
    if arqIniPontes = '' then
        arqIniPontes := sintDirAmbiente + '\pontes.ini';
    if not fileExists (arqIniPontes) then
        arqIniPontes := '.\pontes.ini';
end.
