unit epFTP;

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
  synacode,
  windows,
  sysUtils,
  Classes,
  strUtils;
  
function executarFTP (ponte: TPonte): boolean;
function executarLoginFTP(ponte: TPonte): boolean;

implementation
var
    sock: integer;

function pegaResposta(enviar: string; sock: integer): TStringList;
var
    statusUltIO, s: integer;
    pBuf: PbufRede;
    header: TStringList;
begin
    statusUltIO := ord (writeRede(sock, enviar));
    pBuf := inicBufRede (sock);

    header := TStringList.Create;
    repeat
        statusUltIO := ord (not readlnBufRede (pbuf, s, 30));
        header.add(s);
    until (statusUltIO <> 0) or (s = '');

    Result := header;
end;

function executarFTP (ponte: TPonte): boolean;
begin
    Result := false;

    sock := abreConexao (ponte.Servidor, ponte.Porta);
    if sock < 0 then
        sintWriteln (ERRO_CONEXAO);  {'Erro de conexao' ou seja, soquete menor que 0};
    else
        Result := true;
end;

function executarLoginFTP(ponte: TPonte): boolean;
var
    enviar: string;
    bufferStr: TStringList;
begin
    Result := false;

    enviar := 'USER ' + ponte.Conta + CRLF;
    bufferStr := pegaResposta(enviar, sock);

    if Pos('331', bufferStr[0]) <> 0 then
        begin
            enviar := 'PASS ' + ponte.Senha + CRLF;
            bufferStr := pegaResposta(enviar, sock);

            if Pos('230', bufferStr[0]) <> 0 then
                Result := true;
            else
            if Pos('530', bufferStr[0]) <> 0 then
                sintWriteLn('Senha está incorreta, edite sua ponte com a senha correta.')
            else
                sintWriteLn(ERRO_CONEXAO);
        end
    else
        sintWrite(ERRO_CONEXAO);
end;

end.
