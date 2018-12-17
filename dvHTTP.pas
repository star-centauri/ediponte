unit dvHTTP;

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
  classes,
  synacode,
  windows,
  sysUtils,
  strUtils;

{ Configurações da rotina HTTP }
procedure inicializaHTTP(ponte: TPonte; nomePonte: string);
procedure fechaHTTP;
function createRotaHTTP(caminho: string): Boolean;
function listarArqHTTP(out list: TStringList): Boolean;
function executaOpcaoHTTP(opcao: string; out prosseguir: boolean; nomeArq: string): Boolean;

{ funções e procedures para manipulação de arquivos }
procedure opcoesArqHTTP(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
function downloadFileHTTP (nomeArqBaixar, dir: string): boolean;
function _findFirstHTTP(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec; listar: TStringList): integer;
function _findNextHTTP(var SearchResults: TSearchRec; listar: TStringList): integer;
function _FileExistsHTTP: Boolean;
procedure _assignFileHTTP(var arq: TextFile; nomeArq: string);
procedure _resetHTTP (var FileHandle: TextFile);
function _ioresultHTTP: Integer;
procedure _closeFileHTTP(var FileHandle: TextFile);

{ funções e procedures para manipulação de pastas }
function voltarDirHTTP: Boolean;
function _directoryExistHTTP: Boolean;
procedure _ChDirHTTP(Dir: string);

implementation
var
  statusUltIO: integer;
  rotaAtual: string;
  ponteConectadaHTTP: TPonte;

{--------------------------------------------------------}
{        seleciona um dos diretórios preferidos          }
{--------------------------------------------------------}

function selPreferidos: string;
var p, n, nprefs: integer;
    s, dir, texto, sel, nomeDir: string;
    atalho: char;

const
    SearchTree = 'Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders\';

begin
    result := '';  { se não selecionar, retorna '' }

    writeln;
    //mensagem ('EPSELDIR', 1); { 'Selecione o diretório com as setas' }
    sintWriteLn('Informe um diretório, ou use as setas para preferidos');

    atalho := sintEditaCampo(nomeDir, wherex, wherey, 255, 80, true);
    Writeln;

    if (atalho = CIMA) or (atalho = BAIX) then
    begin
        nprefs := 0;
        for n := 1 to 50 do
            begin
                s := sintAmbiente ('PREFERIDOS', 'DIRPREF' + intToStr (n));
                if s <> '' then nprefs := nprefs + 1;
            end;

        popupMenuCria (0, wherey-1, 50, nprefs, RED);
        for n := 1 to 50 do
            begin
                s := sintAmbiente ('PREFERIDOS', 'DIRPREF' + intToStr (n));
                if s <> '' then
                    begin
                        p := pos (',', s);
                        texto := copy (s, p+1, 99);
                        popupMenuAdiciona ('', texto);
                    end;
            end;

        popupMenuOrdena;
        n := popupMenuSeleciona;
        sel := opcoesItemSelecionado;
        if (n < 1) or (n > 50) then
            mensagem ('EPOK', 1)   {'OK'}
        else
            begin
                for n := 1 to 50 do
                    begin
                        s := sintAmbiente ('PREFERIDOS', 'DIRPREF' + intToStr (n));
                        if s <> '' then
                            begin
                                p := pos (',', s);
                                dir := copy (s, 1, p-1);
                                texto := copy (s, p+1, 99);
                                if texto = sel then break;
                            end;
                    end;

                if upperCase (dir) = '*CONFIG' then
                    begin
                        delete (dir, 1, 7);
                        regGetString (HKEY_CURRENT_USER, SearchTree+'AppData', dir);
                        dir := dir + '\Dosvox';
                        result := dir;
                    end
                else
                if (dir <> '') and (dir[1] = '*') then
                    begin
                        delete (dir, 1, 1);
                        if not regGetString (HKEY_CURRENT_USER, SearchTree+dir, dir) then
                            dir := '@@@'
                        else
                            result := dir;
                    end
                else
                    result := dir;
            end;
        end
    else
        result := nomeDir;
end;

{----------------------------------------------------------------------}
{          Cria caminho de rota de acordo com servidor HTTP            }
{----------------------------------------------------------------------}

function createRotaHTTP(caminho: string): Boolean;
var
    p: integer;
    recurso, conta: string;
begin
    Result := false;
    conta := '';

    if ponteConectadaHTTP.Porta = 80 then
        rotaAtual := 'http://' + ponteConectadaHTTP.Servidor
    else
    if ponteConectadaHTTP.Porta = 443 then
        rotaAtual := 'https://' + ponteConectadaHTTP.Servidor
    else
        begin
            sintWrite('Porta WEB inválida, só é aceita porta 80 ou 443');
            exit;
        end;

    if (Pos('intervox', ponteConectadaHTTP.Servidor) <> 0) or
       (Pos('bibcegos', ponteConectadaHTTP.Servidor) <> 0) then
        conta := '/~' + ponteConectadaHTTP.Conta + '/'
    else
        conta := ponteConectadaHTTP.Conta + '/';

    if (caminho = '') or
       (pos('@\', caminho) <> 0) or
       (caminho[length(caminho)] = '@') then
        begin
            rotaAtual := rotaAtual + conta;
            Result := true;
        end
    else
        begin
            p := pos('@', caminho);
            recurso := copy(caminho, p+1, Length(caminho)-1);
            recurso := StringReplace(recurso, '\', '/', [rfReplaceAll, rfIgnoreCase]);
            
            rotaAtual := rotaAtual + conta + recurso;
            Result := true;
        end;
end;

{----------------------------------------------------------------------}
{                  Faz a chamada com o serviço HTTP                    }
{----------------------------------------------------------------------}

function pegaHeader (protocolo, nomeComput: string; porta: integer; recurso: string;
                     out codRetorno: integer;
                     out novaUrl: string;
                     out pbuf: PbufRede;
                     out soquete: integer;
                     command: string): boolean;

var s: string;
    i: integer;
    header: TStringList;
    aEnviar: string;

begin
    pegaHeader := false;
    codRetorno := 500;
    novaUrl := '';

    if ansiUpperCase(protocolo) = 'HTTPS' then
        soquete := abreConexaoSSL (nomeComput, porta)
    else
        soquete := abreConexao (nomeComput, porta);
    if soquete < 0 then
        begin
            sintWriteln (ERRO_CONEXAO);  {'Erro de conexao' ou seja, soquete menor que 0};
            exit;
        end;

    aEnviar :=
        command + ' ' + EncodeURL(recurso) + ' HTTP/1.0' + CRLF +
        'UA-CPU: x86' + CRLF +
        'Connection: Close' + CRLF +
        'Accept-Language: pt-br' + CRLF +
        'User-Agent: Dosvox ' + '6.0' + CRLF +
        'Host: ' + nomeComput + CRLF +
        CRLF;

    statusUltIO := ord (writeRede(soquete, aEnviar));

    pBuf := inicBufRede (soquete);

    header := TStringList.Create;
    repeat
        statusUltIO := ord (not readlnBufRede (pbuf, s, 30));
        header.add(s);
    until (statusUltIO <> 0) or (s = '');

    if copy(header[0], 1,4) <> 'HTTP' then   // erro no servidor
        begin
            sintWriteln (ERRO_HTTP);
            header.Free;
            fechaConexao(soquete);
            fimBufRede(pbuf);
            pbuf := NIL;
            exit;
        end;

    s := header[0];
    i := pos(' ', s);
    codRetorno := StrToInt(copy(s, i+1, 3));

    if (codRetorno div 100) = 3  then  // relocators
        begin
            // pega o location
            for i := 0 to (header.Count-1) do
                begin
                    if pos('LOCATION:', upperCase(header[i])) = 1 then
                        novaUrl := trim(copy(header[i], 10 , 999));
                end;
            fimBufRede (pbuf);
            fechaConexao(soquete);
        end;

    if (codRetorno div 100) = 4 then // not found
      begin
        pegaHeader := false;
        exit;
      end;

    header.Free;
    pegaHeader := true;
end;

{----------------------------------------------------------------------}
{       Faz a tradução do caminho para iniciar semantica HTTP          }
{----------------------------------------------------------------------}

function traduzURL (url: string; out protocolo, nomeComput: string;
                                 out porta: integer;
                                 out recurso: string): boolean;
var
    i: integer;
    erro: integer;
    s: string;
begin
    traduzURL := false;

    url := trim(url);
    i := pos('://' , url);
    if i = 0 then
        protocolo := 'http'
    else
        begin
            protocolo := copy(url, 1, (i-1));
            url := copy(url, (i+3), 999);
        end;
    protocolo := upperCase(protocolo);

    i := pos('/', url);
    if i = 0 then
        i := pos('?', url);

    if i = 0 then
        begin
            recurso := '';
            nomeComput := url;
        end
    else
        begin
            nomeComput := copy(url, 1, (i-1));
            recurso := copy(url, i, 999);
            if copy(recurso, 1,1) = '?' then
                recurso := '/' + recurso;
        end;

    i := pos(':', nomeComput);
    if i <> 0 then
        begin
            s := copy(nomeComput, (i+1), 999);
            nomeComput := copy(nomeComput, 1, i-1);
            val (s, porta, erro);
            if erro <> 0 then
                exit;
        end
    else
        if protocolo = 'HTTPS' then
            porta := 443
        else
            porta := 80;

    if recurso = '' then
        recurso := '/';

    i := pos('?', recurso);
    if i <> 0 then
        recurso := copy(recurso, 1,i) + EncodeURL(copy(recurso, i+1,999));

    traduzURL := true;
end;

{----------------------------------------------------------------------}
{          Inicialializa as chamadas de tradução da url                }
{----------------------------------------------------------------------}

function abreUrl(url: string; out pBuf: pbufrede; out soquete: integer; command: string): boolean;
var
    protocolo, nomeComput, recurso: string;
    porta: integer;
    novaUrl: string;
    codRetorno: integer;

begin
    abreUrl := false;
    novaUrl := url;

    codRetorno := 300;
    while (codRetorno div 100) = 3  do
        begin
            if not traduzURL (novaUrl, protocolo, nomeComput, porta, recurso) then
                exit;

             if not pegaHeader (protocolo, nomeComput, porta, recurso,
                               codRetorno, novaUrl, pbuf, soquete, command) then
                exit;
       end;

    abreUrl := true;
 end;

{----------------------------------------------------------------------}
{              Ver se diretório existe no servidor HTTP                }
{----------------------------------------------------------------------}

function _directoryExistHTTP: Boolean;
var
    soquete: integer;
    pbuf: PbufRede;
begin
    Result := false;

    if rotaAtual <> '' then
        begin
            abreWinSock;

            if abreUrl(rotaAtual, pbuf, soquete, 'HEAD') then
                Result := true;

            fechaWinSock;
        end;
end;

{----------------------------------------------------------------------}
{              Ver se arquivo existe no servidor HTTP                  }
{----------------------------------------------------------------------}

function _FileExistsHTTP: Boolean;
var
    soquete: integer;
    pbuf: PbufRede;
begin
    Result := false;

    if rotaAtual <> '' then
        begin
            abreWinSock;
            if abreUrl(rotaAtual, pbuf, soquete, 'HEAD') then
                Result := true;

            fechaWinSock;
        end;
end;

{----------------------------------------------------------------------}
{        Extrai dados relevantes do response de conexão HTTP           }
{----------------------------------------------------------------------}

function extrairDados(s: string): string;
var
    p: integer;
    tam, dados: string;
begin
    dados := '';

    // extrai o nome
    p := Pos('<a', s);
    delete (s, 1, p);
    p := Pos('">', s);
    delete(s, 1, p+1);
    p := Pos('</a', s);
    dados := dados + copy(s, 1, p-1);

    // extrai a data
    p := Pos('">', s);
    delete(s, 1, p+1);
    p := Pos('</td', s);
    dados := dados + '|' + trim(copy(s, 1, p-1));

    // extrai o tamanho
    p := Pos('">', s);
    delete(s, 1, p+1);
    p := Pos('</td', s);
    tam := trim(copy(s, 1, p-1));

    if tam <> '' then
      if tam[length(tam)] = 'K' then
          begin
              tam := trim(copy(tam, 1, length(tam)-1));
              dados := dados + '|' + IntToStr(round(pegaReal(tam) * 1024));
          end
      else
      if tam[length(tam)] = 'M' then
          begin
              tam := trim(copy(tam, 1, length(tam)-1));
              dados := dados + '|' + IntToStr(round(pegaReal(tam) * 1024 * 1024));
          end
      else
      if tam[1] in ['0'..'9'] then
          begin
              tam := trim(copy(tam, 1, length(tam)));
              dados := dados + '|' + IntToStr(round(pegaReal(tam)));
          end
      else
          dados := dados + '|' + IntToStr(-1);   // subdiretório

      extrairDados := dados;
end;

{----------------------------------------------------------------------}
{           Retorna valor do response da busca pela conta              }
{----------------------------------------------------------------------}

function listarArqHTTP(out list: TStringList): Boolean;
var
   i, soquete: integer;
   pbuf: PbufRede;
   s: string;
   arq: TStringList;
begin
    Result := false;
    arq := TStringList.Create;

    if abreUrl(rotaAtual, pbuf, soquete, 'GET') then
        begin
          repeat
            statusUltIO := ord (not readlnBufRede (pbuf, s, 30));
            arq.add(s);
          until (statusUltIO <> 0);

          Result := true;
        end
    else
        exit;

    list.Add('..|0|0');
    for i := 0 to arq.Count - 1 do
        begin
            if (Pos('<tr><td valign="top">', arq[i]) = 1) and (Pos('Parent Directory', arq[i]) = 0) then
                begin
                    list.Add(extrairDados(arq[i]));
                end;
        end;
end;

{----------------------------------------------------------------------}
{    Ler arquivo padrão para liberação dos arquivos compartilhando     }
{----------------------------------------------------------------------}

function lerArquivoPadrao(var listar: TStringList): integer;
var
    index, s: string;
    pbuf: PbufRede;
    soquete: integer;
begin
    result := 1;
    index := rotaAtual + '00index.txt';

    if abreUrl(index, pbuf, soquete, 'GET') then
        repeat
            statusUltIO := ord (not readlnBufRede (pbuf, s, 30));
            if s <> '' then
                listar.add(s + '|0|0');
            result := result + 1;
        until (statusUltIO <> 0);
end;

{----------------------------------------------------------------------}
{                função findFirst para protocolo HTTP                  }
{----------------------------------------------------------------------}

function _findFirstHTTP(FileMask: string; Attributes: Integer; var SearchResult: TSearchRec; listar: TStringList): integer;
var
    ehDir, aux, item, dir: string;
    lengthDir, p: integer;
begin
    ponteiro_prox := 0;
    ehDir := '';
    lengthDir := listar.Count;

    if lengthDir = 1 then
        lengthDir := lerArquivoPadrao(listar);

    if (FileMask = '*') or
       (FileMask = '?') or
       (FileMask = '*.*') or
       (FileMask = '*.**') then
        begin
            aux := listar[ponteiro_prox];

            //Pegar nome
            p := Pos('|', aux);
            item := copy(aux, 1, p-1);
            p := Pos('/', item);
            if p <> 0 then ehDir := ' Diretório';
            dir := item + ehDir;
            SearchResult.Name := dir;
            StrPCopy(SearchResult.FindData.cFileName, dir);

            //Pegar tamanho
            p := Pos('|', aux);
            delete(aux, 1, p);
            p := Pos('|', aux);
            item := copy(aux, p+1, length(aux)-1);
            SearchResult.Size := StrToInt(item);
        end;
    Result := 0;
end;

{----------------------------------------------------------------------}
{                função findNext para protocolo HTTP                   }
{----------------------------------------------------------------------}

function _findNextHTTP(var SearchResults: TSearchRec; listar: TStringList): integer;
var
    ehDir, aux, item, dir: string;
    p: integer;
begin
    if (listar.Count = 1) or (ponteiro_prox = listar.Count) then
        Result := 1
    else
        begin
            ehDir := '';
            aux := listar[ponteiro_prox];

            //Pegar nome
            p := Pos('|', aux);
            item := copy(aux, 1, p-1);
            p := Pos('/', item);
            if p <> 0 then ehDir := ' Diretório';
            dir := item + ehDir;
            SearchResults.Name := dir;
            StrPCopy(SearchResults.FindData.cFileName, dir);

            //Pegar tamanho
            p := Pos('|', aux);
            delete(aux, 1, p);
            p := Pos('|', aux);
            item := copy(aux, p+1, length(aux)-1);
            SearchResults.Size := StrToInt(item);

            Result := 0;
        end;
end;

{----------------------------------------------------------------------}
{                procedure ChDir para protocolo HTTP                   }
{----------------------------------------------------------------------}

procedure _ChDirHTTP(Dir: string);
begin
    Dir := StringReplace(Dir, '\', '/', [rfReplaceAll, rfIgnoreCase]);
    rotaAtual := rotaAtual + Dir;
end;

function voltarDirHTTP: Boolean;
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

    if pos(ponteConectadaHTTP.Conta, rotaAtual) <> 0 then
        Result := true;
end;

{----------------------------------------------------------------------}
{       Copia o conteúdo do arquivo remoto para um arquivo local       }
{----------------------------------------------------------------------}

function copiaURLparaArquivo (pbuf: PbufRede; soquete: integer;
                          nomeArqBaixar: string): boolean;
const
    TAMBUF = 8192;
var
    arq: file;
    lidoOk: boolean;
    buf: packed array [0..TAMBUF-1] of char;
    ncbuf: integer;
    c: char;
    escritos: integer;
begin
     copiaURLparaArquivo := false;
     statusUltIO := 0;
     ncbuf := 0;

     assign (arq, nomeArqBaixar);
     {$I-}  rewrite (arq, 1);  {$I+}
     if ioresult <> 0 then
         begin
             statusUltIO := 1;
             sintWriteln(ERRO_ESCRITA);
             exit;
         end;

    // versão futura: checar o content-Length previamente recebido
    // se não tiver vindo, considerar tamanho infinito.

    inicializaProgresso(100, 50, 50, false, 10);

    repeat
        lidoOk := leCaracBufRede(pbuf, c);
        if lidoOk then
            begin
                buf[ncbuf] := c;
                ncbuf := ncbuf + 1;
            end;

        if ncbuf >= TAMBUF then
            begin
                escritos := 0;
                mostraProgresso(escritos, ncbuf);
                blockWrite (arq, buf, ncbuf, escritos);

                if escritos <> ncbuf then
                    begin
                        sintWriteln(ERRO_ESCRITA);
                        statusUltIO := 1;
                        lidoOk := false;
                    end;
                ncbuf := 0;
            end;
    until not lidoOk;

    if ncbuf <> 0 then
        begin
            escritos := 0;
            mostraProgresso(escritos, ncbuf);
            blockWrite (arq, buf, ncbuf, escritos);
            if escritos <> ncbuf then
                begin
                    sintWriteln(ERRO_ESCRITA);
                    statusUltIO := 1;
                end;
            end;

    closeFile (arq);
    finalizaProgresso;
    copiaURLparaArquivo := true;
end;

{----------------------------------------------------------------------}
{         Download do arquivo por meio do protocolo HTTP               }
{----------------------------------------------------------------------}

function downloadFileHTTP (nomeArqBaixar, dir: string): boolean;
var
    pbuf: PbufRede;
    soquete: integer;
begin
    Result := false;

    if pos(nomeArqBaixar, rotaAtual) = 0 then
        _ChDirHTTP(nomeArqBaixar);

    if dir = '' then dir := GetCurrentDir;
    if FileExists(dir + '\' + nomeArqBaixar) then
        begin
            sintWriteLn('Arquivo já existe no diretório ' + dir);
            sintWrite('Deseja substituir? ');

            if popupMenuPorLetra('SN') = 'S' then
                DeleteFile(dir + '\' + nomeArqBaixar)
            else
                exit;
        end;

    abreWinSock;
    if abreUrl(rotaAtual, pbuf, soquete, 'GET') then
        begin
            if copiaURLparaArquivo (pbuf, soquete, nomeArqBaixar) then
                Result := true;
            fimBufRede(pbuf);
            fechaConexao(soquete);
        end;

    fechaWinSock;
end;

function propriedadesArq(nomeArq: string): Boolean;
const
    TAMBUF = 8192;
var
    pbuf: PbufRede;
    header: TStringList;
    soquete, codRetorno, i: integer;
    aEnviar, novaUrl, aux, s: string;
begin
    Result := false;
    codRetorno := 500;
    novaUrl := ' ';

    if pos(nomeArq, rotaAtual) = 0 then
        _ChDirHTTP(nomeArq);

    abreWinSock;
    soquete := abreConexao (ponteConectadaHTTP.Servidor, ponteConectadaHTTP.Porta);

    if soquete < 0 then
        begin
            sintWriteln (ERRO_CONEXAO);  {'Erro de conexao' ou seja, soquete menor que 0};
            exit;
        end;

    aEnviar :=
        'HEAD ' + EncodeURL(rotaAtual) + ' HTTP/1.0' + CRLF +
        'UA-CPU: x86' + CRLF +
        'Connection: Close' + CRLF +
        'Accept-Language: pt-br' + CRLF +
        'User-Agent: Dosvox ' + '6.0' + CRLF +
        'Host: ' + ponteConectadaHTTP.Servidor + CRLF +
        CRLF;

    statusUltIO := ord (writeRede(soquete, aEnviar));

    pBuf := inicBufRede (soquete);

    header := TStringList.Create;
    repeat
        statusUltIO := ord (not readlnBufRede (pbuf, s, 30));
        header.add(s);
    until (statusUltIO <> 0) or (s = '');

    if copy(header[0], 1,4) <> 'HTTP' then   // erro no servidor
        begin
            sintWriteln (ERRO_HTTP);
            header.Free;
            fechaConexao(soquete);
            fimBufRede(pbuf);
            pbuf := NIL;
            exit;
        end;

    s := header[0];
    i := pos(' ', s);
    codRetorno := StrToInt(copy(s, i+1, 3));

    if (codRetorno div 100) = 3  then  // relocators
        begin
            // pega o location
            for i := 0 to (header.Count-1) do
                begin
                    if pos('LOCATION:', upperCase(header[i])) = 1 then
                        novaUrl := trim(copy(header[i], 10 , 999));
                end;
            fimBufRede (pbuf);
            fechaConexao(soquete);
        end;

    if (codRetorno div 100) = 4 then
        exit;
    
    for i := 0 to header.Count-1 do
        begin
            if pos('Last-Modified:', header[i]) <> 0 then
                begin
                    aux := formatarDataPT(copy(header[i], 16, Length(header[i])));
                    sintWriteLn('Última modificação: ' + aux);
                end
            else
            if pos('Content-Length:', header[i]) <> 0 then
                sintWriteLn('Tamanho Arquivo (em MB): ' + FloatToStr(pegaReal(copy(header[i], 17, Length(header[i])))/1000000))
            else
            if pos('Content-Type:', header[i]) <> 0 then
                sintWriteLn('Tipo arquivo: ' + copy(header[i], 14, Length(header[i])));
        end;

    header.Free;
    fechaWinSock;
end;

procedure opcoesArqHTTP(out listaOpcoes: TStringList; var tabLetrasOpcao: string);
begin
    tabLetrasOpcao := 'EBPT' + ESC;

    listaOpcoes.Add('E - Baixar Arquivo e editar');
    listaOpcoes.Add('B - Baixar Arquivo');
    listaOpcoes.Add('P - Propriedades do Arquivo');
    listaOpcoes.Add('T - Terminar');
end;

function executaOpcaoHTTP(opcao: string; out prosseguir: boolean; nomeArq: string): Boolean;
begin
    Result := true;
    
    if opcao = 'B' then
        begin
            if not baixarArq(nomeArq) then
                Result := false;
            prosseguir := false;
            voltarDirHTTP;
        end
    else
    if opcao = 'E' then
        begin
            if EditarArq(nomeArq) then
                begin
                    prosseguir := false;
                    voltarDirHTTP;
                end;
        end
    else
    if opcao = 'P' then
        begin
            if not propriedadesArq(nomeArq) then
                Result := false;
            voltarDirHTTP;
            prosseguir := true;
        end
    else
    if (opcao = ESC) or (opcao = 'T') then
        begin
            limpaBaixo(WhereY);
            prosseguir := false;
            result := false;
            opcao := 'N';
        end;
end;

procedure _assignFileHTTP(var arq: Text; nomeArq: string);
begin
    if pos(nomeArq, rotaAtual) = 0 then
        _ChDirHTTP(nomeArq);
    AssignFile(arq, nomeArq);
end;

procedure _resetHTTP (var FileHandle: TextFile);
var
  nomeRota: string;
  p: integer;
begin
    abreWinSock;
    nomeRota := copy(rotaAtual, 1, length(rotaAtual));
    p := Pos('/', nomeRota);
    
    while p <> 0 do
        begin
            delete(nomeRota, 1, p);
            p := Pos('/', nomeRota);
        end;

    if not downloadFileHTTP(nomeRota, '') then
        begin
            ERRO := ERRO_ESCRITA;
            exit;
        end;

    fechaWinSock;
    Reset(FileHandle);
end;

function _ioresultHTTP: Integer;
begin
    Result := 0;

    if tipoDeErro <> 'ND' then
        Result := 1;
end;

procedure _closeFileHTTP(var FileHandle: TextFile);
var
  nomeArq, dir, dirAntigo: string;
  p: integer;
  c: char;
begin
    nomeArq := copy(rotaAtual, 1, length(rotaAtual));
    p := Pos('/', nomeArq);

    while p <> 0 do
        begin
            delete(nomeArq, 1, p);
            p := Pos('/', nomeArq);
        end;

    sintWriteLn('Deseja manter no diretório atual? '); //mensagem
    c := popupMenuPorLetra('SN');

    if c = ESC then exit;

    if UpperCase(c) = 'N' then
    begin
        dir := selPreferidos;
        if (dir = '') and (dir = ESC) then
            exit;

        tituloJanela('baixando ' + nomeArq);

        MoveFile(PChar(nomeArq), PChar(dir + '\' + nomeArq));
        DeleteFile(nomeArq);
    end;
end;


procedure inicializaHTTP(ponte: TPonte; nomePonte: string);
begin
    ponteConectadaHTTP := ponte;
    if not createRotaHTTP(nomePonte) then
        begin
            ERRO := ERRO_CONEXAO;
            exit;
        end;

    sintetiza('ponte HTTP conectada.');
end;

procedure fechaHTTP;
begin
    rotaAtual := '';
end;
end.
