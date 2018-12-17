unit epvars;

interface
uses
    dvwin,
    dvcrt,
    dvform,
    epMsg,
    minireg,
    Windows,
    sysUtils;

const
    VERSAO = '2.0';

type
    DataType = (Nada, Arquivo, Diretorio);
    TPonte = record
        Nome      : string;
        Tipo      : string;
        Servidor  : string;
        Porta     : smallint;
        Conta     : string;
        Senha     : string;
    end;


var
    nomePonte: string;
    ambiente: string;
    arq: TextFile;
    ERRO: string;             { Variavel para captura tipo de erro na conexão }
    ponteiro_prox: integer;
    atalhoRapido: boolean; { Variavél para informa se usuário digitou atalho direto a ponte }

function pegaReal (s: string): real;
function selPreferidos: string;
function aplicaSenha (texto: string): string;
function formatarDataPT (texto: string): string;

implementation

{----------------------------------------------------------------------}
{           mudar , pra . em números com casas decimais                }
{----------------------------------------------------------------------}

function pegaReal (s: string): real;
begin
    DecimalSeparator := '.';
    result := strToFloat(s);
end;

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

{--------------------------------------------------------}
{                  Criptografar senha                    }
{--------------------------------------------------------}

function aplicaSenha (texto: string): string;
var i: integer;
    modelo: string;
    x, y: integer;
begin
    modelo := '';
    x := length(texto);
    y := 54;
    for i := 1 to 80 do
        begin
             x := (x + y + i) mod 16;
             y := x;
             modelo := modelo + chr(x);
        end;

    for i := 1 to length(texto) do
        texto[i] := chr(ord(texto[i]) xor ord(modelo[i]));

    result := texto;
end;

{--------------------------------------------------------}
{           Formatação da dat para português             }
{--------------------------------------------------------}

function formatarDataPT (texto: string): string;
var
    dados: string;
    p: integer;
begin
    dados := ' ';
    p := Pos(',', texto);

    if p <> 0 then
        dados := copy(texto, p+1, Length(texto)-7)
    else
        dados := texto;

    if pos('Jan', dados) <> 0 then
        dados := StringReplace(dados, 'Jan', 'Janeiro', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Feb', dados) <> 0 then
        dados := StringReplace(dados, 'Feb', 'Fevereiro', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Mar', dados) <> 0 then
        dados := StringReplace(dados, 'Mar', 'Março', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Apr', dados) <> 0 then
        dados := StringReplace(dados, 'Apr', 'Abril', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('May', dados) <> 0 then
        dados := StringReplace(dados, 'May', 'Maio', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Jun', dados) <> 0 then
        dados := StringReplace(dados, 'Jun', 'Junho', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Jul', dados) <> 0 then
        dados := StringReplace(dados, 'Jul', 'Julho', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Aug', dados) <> 0 then
        dados := StringReplace(dados, 'Aug', 'Agosto', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Sep', dados) <> 0 then
        dados := StringReplace(dados, 'Sep', 'Setembro', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Oct', dados) <> 0 then
        dados := StringReplace(dados, 'Oct', 'Outubro', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Nov', dados) <> 0 then
        dados := StringReplace(dados, 'Nov', 'Novembro', [rfReplaceAll, rfIgnoreCase])
    else
    if pos('Dec', dados) <> 0 then
       dados := StringReplace(dados, 'Dec', 'Dezembro', [rfReplaceAll, rfIgnoreCase]);

    Result := dados;
end;

begin
    ERRO := ' ';
    atalhoRapido := false;
end.
