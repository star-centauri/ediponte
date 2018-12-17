unit epeditor;

interface
uses
  dvcrt,
  dvform,
  dvWin,
  dvamplia,
  epMsg,
  epVars,
  epConvert,
  Windows,
  sysUtils,
  strUtils;

function EditarArq(nomeArq: string): boolean;
function baixarArq(nomeArq: string): boolean;
procedure inicEditor;
procedure edita;

implementation
uses
  dvArq2,
  dvPonte;

const
    MAXLIN = 20000;
    TAMLINHA = 250;

type
    tlinha = string[TAMLINHA];
    plinha = ^tlinha;

var
    linhas: array [1..MAXLIN] of plinha;
    buscado: string;
    editando: boolean;
    nlin, linAtual: integer;

{----------------------------------------------------------------------}
{                 inicializa variáveis do editor                       }
{----------------------------------------------------------------------}

procedure inicEditor;
begin
    nlin := 1;
    new (linhas [1]);
    linhas [1]^ := '';
    linAtual := 1;
    buscado := '*(&%^#$&*^@%*^&@#%*$';   {lixo}
end;

{----------------------------------------------------------------------}
{                    gravar alterações no arquivo                      }
{----------------------------------------------------------------------}

function gravaArquivo: boolean;
var i: integer;
label erro;
begin
     gravaArquivo := true;

     {$I-} rewrite (arq);  {$I+}
     if ioresult <> 0 then
         begin
erro:
             clrScr;
             mensagem ('EPERRGRV', 1);  {'Erro de gravacao.'}
             mensagem ('EPUSEF2',  1);  {'Use ctrl F2 para trocar o nome'}
             gravaArquivo := false;
             {$I-} close (arq);  {$I+}
             if ioresult <> 0 then;
             while sintFalando do;
             exit;
         end;

     for i := 1 to nlin do
         begin
             {$I-}writeln (arq, linhas [i]^);  {$I+}
             if ioresult <> 0 then
                 goto erro;
         end;

     if not editando then
         for i := 1 to nlin do
             dispose (linhas [i]);

     close (arq);
     clrscr;
     sintWriteLn('Arquivo gravado.');
     //mensagem ('EPARQGRV', 1);  {'Arquivo gravado'}
end;

{----------------------------------------------------------------------}
{                 Exibir tela de edição do arquivo                     }
{----------------------------------------------------------------------}

procedure mostraTela;
var i: integer;
begin
    for i := 4 to 24 do
        begin
            gotoxy (1, i);
            if ((linAtual + i - 13) > 0) and
               ((linAtual + i - 13) <= nlin) then
                write (linhas[linAtual+i-13]^);
            clreol;
        end;
    gotoxy (1, 25);
    clreol;
    textBackGround (BLUE);

    gotoxy (10, 25);
    write (linAtual);
    gotoxy (20, 25);
    write (nomePonte);
    gotoxy (50, 25);
    write ('Aperte F9 para ajuda');
    textBackGround (BLACK);
end;

{----------------------------------------------------------------------}
{                             Ordenar                                  }
{----------------------------------------------------------------------}

procedure ordena;
var i, j: integer;
    temp: plinha;
    c: char;
begin
     gotoxy (1, 1); clreol;
     textBackground (RED);
     mensagem ('EPCNFORD', 0);  {'Aperte S para confirmar ordenação'}
     textBackground (BLACK);
     c := popupMenuPorLetra('SN');
     if c <> 'S' then
         begin
             mensagem ('EPDESIST', -1);  {Desistiu}
             exit;
         end;

     mensagem ('EPESPERE', -1);  {'Espere'}

     while (nlin > 1) and (linhas [nlin]^ = '') do
         begin
             dispose (linhas [nlin]);
             nlin := nlin - 1;
         end;

     if upcase (c) = 'S' then
         begin
             for i := 1 to nlin-1 do
                 for j := i+1 to nlin do
                       begin
                           if linhas [i]^ > linhas [j]^ then
                               begin
                                   temp := linhas [i];
                                   linhas [i] := linhas [j];
                                   linhas [j] := temp;
                               end;
                       end;

             linAtual := 1;
         end;

     mensagem ('EPOK', -1);  {'OK'}
end;

{----------------------------------------------------------------------}
{                 Edição do arquivo selecionado                        }
{----------------------------------------------------------------------}

procedure edita;
var s: string;
    i: integer;
    c, retorno: char;
    salvaLin: integer;

label mvcima, mvbaixo, insereLinha, achou, buscaDeNovo;
begin
    editando := true;

    while editando do
        begin
            mostraTela;
            s := linhas [linAtual]^;

            if not keypressed then
                if s = '' then
                    sintClek
                else
                    sintetiza (s);

            retorno := sintEditaCampo (s, 1, 13, TAMLINHA, 80, true);
            linhas [linAtual]^ := s;

            case retorno of
                CIMA:
                     begin
    mvcima:
                         linAtual := linAtual - 1;
                         if linAtual <= 0 then
                             begin
                                 sintBip;
                                 delay (200);
                                 linAtual := 1;
                             end;
                     end;
                BAIX:
                     begin
    mvbaixo:
                         linAtual := linAtual + 1;
                         if linAtual > nlin then
                             begin
                                 sintBip;
                                 delay (200);
                                 linAtual := nlin;
                             end;
                     end;
                PGUP:
                     begin
                         linAtual := linAtual - 19;
                         goto mvcima;
                     end;

                PGDN:
                     begin
                         linAtual := linAtual + 19;
                         goto mvbaixo;
                     end;

                CTLPGUP:  linAtual := 1;
                CTLPGDN:  linAtual := nlin;

                CTLENTER:
                    if nlin <= MAXLIN then
                        begin
               insereLinha:
                            for i := nlin downto linAtual  do
                                linhas [i+1] := linhas [i];
                            nlin := nlin+1;
                            new (linhas [linAtual]);
                            linhas [linAtual]^ := '';
                            mensagem ('EPNOVLIN', -1);  {'Nova linha'}
                        end
                    else
                        mensagem ('EPSEMMEM', -1);  {'Memória esgotada'}

                ENTER:
                    if nlin > MAXLIN then
                        mensagem ('EPSEMMEM', -1)  {'Memória esgotada'}
                    else
                        begin
                            linAtual := linAtual+1;
                            goto insereLinha;
                        end;

                CTLF2:   begin
                               gotoxy (1, 1);  clreol;
                               textBackground (RED);
                               mensagem ('EPNOMARQ', 0);  {'Nome do arquivo ? '}
                               textBackground (BLACK);
                               sintReadln (s);
                               if nomePonte <> '' then
                                    begin
                                        nomePonte := s;
                                        tituloJanela (nomePonte);
                                        _assignFile(arq, nomePonte);
                                    end;
                         end;

                F2:  if gravaArquivo then;

                F3:  begin
                  	 str (linAtual, s);
                         mensagem ('EPLINHA', -1);  {'Linha '}
                         sintetiza (s);
                         delay (500);
                     end;

              { F4: tratado pela rotina de edicao }

                F5:  begin
                         gotoxy (1, 1); clreol;
                         textBackground (RED);
                         mensagem ('EPTXTBUS', 0);  {'Informe o texto buscado '}
                         textBackground (BLACK);
                         sintReadln (buscado);
                         salvaLin := linAtual;
              buscaDeNovo:
                         if buscado = '' then
                             for i := linAtual to nlin do
                                 begin
                                     if linhas [i]^ = '' then
                                     begin
                                          linAtual := i;
                                          mensagem ('EPOK', -1);
                                          goto achou;
                                     end;
                                 end
                         else
                             for i := linAtual to nlin do
                                 if pos (buscado, linhas[i]^) <> 0 then
                                     begin
                                          linAtual := i;
                                          mensagem ('EPOK', -1);
                                          goto achou;
                                     end;

                         linAtual := salvaLin;
                         mensagem ('EPNAOACH', -1);  {'Não achou'}
              achou:
                     end;

                CTLF5: begin
                           salvaLin := linAtual;
                           linAtual := linAtual + 1;
                           goto buscaDeNovo;
                       end;

                F6:  ordena;

                F7:
                     begin
                         if nlin <> 1 then
                             begin
                                 dispose (linhas [linAtual]);
                                 nlin := nlin-1;
                                 for i := linAtual to nlin do
                                     linhas [i] := linhas [i+1];
                             end
                         else
                             linhas [1]^ := '';
                         if linAtual > nlin then linAtual := nlin;
                         mensagem ('EPLINREM', -1);  {'linha removida'}
                     end;

              { F4: tratado pela rotina de edicao }

                F9:
                    begin
                       clrscr;
                       textBackground (BLUE);
                       mensagem ('EPAJU01', 1);  {'As principais opções deste programa são'}
                       textBackground (BLACK);
                       mensagem ('EPAJU02', 1);  {'ENTER insere linha'}
                       mensagem ('EPAJU03', 1);  {'F1    fala palavra'}
                       mensagem ('EPAJU04', 1);  {'F2    grava'}
                       mensagem ('EPAJU05', 1);  {'F3    informa linha atual'}
                       mensagem ('EPAJU06', 1);  {'F4    controle da soletragem'}
                       mensagem ('EPAJU07', 1);  {'F5    busca trecho'}
                       mensagem ('EPAJU08', 1);  {'F6    ordena arquivo'}
                       mensagem ('EPAJU09', 1);  {'F7    remove linha atual'}
                       mensagem ('EPAJU10', 1);  {'F8    Informa hora'}
                       mensagem ('EPAJU11', 1);  {'F9    ajuda'}
                       mensagem ('EPAJU12', 1);  {'ESC termina'}
                       writeln;
                       textBackground (BLUE);
                       mensagem ('EPTENTER', 1);  {'Pressione Enter'}
                       textBackground (BLACK);
                       readln;
                   end;

                ESC:
                     begin
                         clrscr;
                         textBackground (BLUE);
                         mensagem ('EPCNFFIM', 0);  {'Confirma fim ? '}
                         textBackground (BLACK);
                         c := popupMenuPorLetra ('SN');
                         if c = 'S' then
                             begin
                                 editando := false;
                                 gravaArquivo;
                             end
                         else
                             clrscr;
                     end;
            end;
        end;
end;

{--------------------------------------------------------}
{            testa o tipo da extensão
{--------------------------------------------------------}

function extIS (filename, ext: string): boolean;
begin
    if (ext <> '') and (ext[1] <> '.') then
        ext := '.' + ext;
        result :=(AnsiEndsText(upperCase(ext), upperCase(filename)));
end;

{----------------------------------------------------------------------}
{              Ação para editar arquivo 'Remotamente'                  }
{----------------------------------------------------------------------}

function EditarArq(nomeArq: string): boolean;
var
   traduzOem: boolean;
   ehHTML: boolean;
   salva: integer;
   c: char;
   s: string;
label vaiEditar;
{-----------------------------------------------------------------------}
    function traduzParaAnsi (s: string): string;
        begin
            s := s + #$0;
            OemToAnsi (@s[1], @s[1]);
            traduzParaAnsi := copy (s, 1, length (s)-1);
        end;
{-----------------------------------------------------------------------}
    function extensaoValidaEdicao(nomeArq: string): boolean;
        begin
            extensaoValidaEdicao := extIs(nomeArq, '.txt') or
                                    extIs(nomeArq, '.pas') or
                                    extIs(nomeArq, '.cmd') or
                                    extIs(nomeArq, '.js') or
                                    extIs(nomeArq, '.dpr') or
                                    extIs(nomeArq, '.c') or
                                    extIs(nomeArq, '.py') or
                                    extIs (nomeArq, '.java') or
                                    extIs (nomeArq, '.dat') or
                                    extIs (nomeArq, '.htm') or
                                    extIs (nomeArq, '.html') or
                                    extIS (nomeArq, '.atu');
        end;
{-----------------------------------------------------------------------}
begin
    EditarArq := false;
    ehHTML := extIs (nomeArq, '.htm') or extIs (nomeArq, '.html');

    salva := amplFator;
    amplFim;
    amplInic (25-salva, salva);

     if not extensaoValidaEdicao(nomeArq) then
     begin
         mensagem('EPINVED', 1); {Extensão do arquivo inválida para edição.}
         mensagem('EPOUTOP', 1); {Escolha outra opção.}
         limpaBaixo(WhereY-1);
         exit;
     end;

    ClrScr;
    amplFim;
    amplInic (1, salva);

    tituloJanela (nomeArq);
    inicEditor;

    _assignFile (arq, nomeArq);
    if not _fileExists(nomeArq) then
        exit;
    {$I-} _reset (arq);  {$I+}
    if _ioresult <> 0 then
        exit;

    if ehHTML then
         begin
             htmlToText(nomeArq);
             _assignFile (arq, nomeArq);
             if not _fileExists(nomeArq) then
                 exit;
             {$I-} _reset (arq);  {$I+}
            if _ioresult <> 0 then
                exit;
         end;

    traduzOem := false;    ////// mudar depois isso

    if not _eof (arq) then    { arquivo existe e não está vazio }
        begin
            dispose (linhas [1]);
            nlin := 0;
        end;

    while not _eof (arq) do
        begin
            readln (arq, s);
            nlin := nlin + 1;
            new (linhas [nlin]);
            linhas[nlin]^ := '';
            while length (s) > 0 do
                begin
                    if traduzOem then
                        linhas [nlin]^ := traduzParaAnsi (copy (s, 1, TAMLINHA))
                    else
                        linhas [nlin]^ := copy (s, 1, TAMLINHA);
                    delete (s, 1, TAMLINHA);
                    if length (s) > 0 then
                        begin
                            if nlin >= MAXLIN then exit;
                            nlin := nlin + 1;
                            new (linhas [nlin]);
                        end;
                end;
        end;

    vaiEditar:
    sintApagaAuto := false;
    edita;

    result := true;
    ClrScr;
    _CloseFile(arq);
end;

function baixarArq(nomeArq: string): boolean;
var
    fileArq: TextFile;
    c: Char;
    dir: string;
begin
    result := false;
    mensagem('EPBAIXA', 0); {Deseja baixar no diretório atual? }
    c := popupMenuPorLetra('SN');

    if c = ESC then exit;

    if UpperCase(c) = 'N' then
    begin
        dir := selPreferidos;
        if (dir <> '') and (dir <> ESC) then
            ChDir(dir)
        else
            exit;
    end;

    tituloJanela('baixando ' + nomeArq);
    Result := downloadFile(dir, nomeArq);
end;


end.
