unit epProcessa;

interface

uses
  dvcrt,
  dvWin,
  dvArq2,
  dvPonte,
  dvform,
  dvamplia,
  dvinet,
  minireg,
  epMsg,
  epvars,
  epError,
  Windows,
  sysUtils,
  Classes,
  strUtils;

procedure processar;

implementation

{----------------------------------------------------------------------}
{            Menu de opções para o arquivo selecionado                 }
{----------------------------------------------------------------------}

function opcoesArq(tipoDado: string; var validarOpcao: boolean): Char;
var
    n, i: integer;
    atalho1, atalho2: char;
    nomeOpcao: string;
    listaOpcoes: TStringList;
    tabLetrasOpcao: string;

begin
    Result := ESC;
    validarOpcao := false;
    listaOpcoes := TStringList.Create;

    if tipoDado = 'A' then
        validarOpcao := opcoesArqProtocolos(listaOpcoes, tabLetrasOpcao)
    else
        validarOpcao := opcoesDirProtocolos(listaOpcoes, tabLetrasOpcao);


    if validarOpcao then
        begin
            limpaBaixo(WhereY-2);
            mensagem('EPARQOP', 0); {O que deseja fazer?}
            sintLeTecla (atalho1, atalho2);

            if (atalho1 = #0) and ((atalho2 = CIMA) or (atalho2 = BAIX)) then
                begin
                    garanteEspacoTela(9);
                    popupMenuCria (wherex, wherey, 50, length(tabLetrasOpcao), RED);

                    for i := 0 to (listaOpcoes.Count-1) do
                       popupMenuAdiciona ('', listaOpcoes[i]);

                    n := popupMenuSeleciona;
                    if n > 0 then
                        result := tabLetrasOpcao[n];
                end
            else
                Result := atalho1;
        end;
end;

{----------------------------------------------------------------------}
{           Seleciona a ação que foi pedida pelo usuário               }
{----------------------------------------------------------------------}

function executaOpcao(var opcao: char; nomeArq: string; tipoDado: Char): boolean;
var
    s: string;
    prosseguir, validaOpcao: boolean;
begin
    prosseguir := true;
    result := true;

    while prosseguir do
        begin
            opcao := UpCase(opcoesArq(tipoDado, validaOpcao));

            if validaOpcao then
                begin
                    if Pos(opcao, opcoesItemSelecionado) <> 0 then
                        begin
                            Writeln(opcoesItemSelecionado);
                            s := copy ( opcoesItemSelecionado, 1, pos ('-', opcoesItemSelecionado)-2 );
                        end;

                    writeln;
                    if opcao = ESC then
                        begin
                            limpaBaixo(WhereY);
                            Result := false;
                            prosseguir := false;
                        end
                    else
                        Result := executaOpcaoProtocol(opcao, prosseguir, nomeArq, tipoDado);
                end
            else
                begin
                    limpaBaixo(WhereY);
                    Result := false;
                    prosseguir := false;
                end;
        end;
end;

{----------------------------------------------------------------------}
{                 ve se ponte existe e é acessível
{----------------------------------------------------------------------}

function ponteExiste (nomePonte: string): boolean;
var
    erro: string;
begin
    Result := false;

    if not ponteFoiCriada(nomePonte) then
        begin
            erro := tipoDeErro;

            if erro = ERRO_DIG then
                sintWriteLn('Ponte digitada incorretamente.' + ^m^j +
                'Digite como no exemplo: [nomePonte]@[rotaArquivo]')
            else
            if  erro = ERRO_PNC then
                sintWriteLn('Ponte não foi criada. Consulte o PonteVox.');

            exit;
        end;
end;

{----------------------------------------------------------------------}
{              Retorna se arquivo ou diretório existe                  }
{----------------------------------------------------------------------}

function existeArqOuDir(dadoInformado: string): char;
begin
    result := 'N';

    if dadoInformado[length(dadoInformado)] = '\' then
        if _directoryexists(dadoInformado) then
            result := 'D'
        else
            sintWriteLn('Diretório inexistente. Tente novamente')
    else
        if _fileExists(dadoInformado) then
            result := 'A'
        else
            sintWriteLn('Arquivo inexistente. Tente novamente');
end;

{----------------------------------------------------------------------}
{                    Vai andando entre diretorios                      }
{----------------------------------------------------------------------}

function lendoRota(var nomePonte: string): string;
var
    n: integer;
    navegando: boolean;
    opcao: char;
begin
    navegando := true;

    while navegando do
        begin
            limpaBaixo(2);
            nomePonte := StringReplace(nomePonte, '/', '\', [rfReplaceAll, rfIgnoreCase]);
            criaListArq('*.*', faAnyFile);

            sintWriteLn('Folheie e escolha sua opção'); //mensagem

            preparaTelaArq (wherex, wherey, 80, wherey+14);
            salvaTelaArq;

            n := escolheListArq(0);

            if n >= 0 then
                begin
                    nomePonte := buscaSel(n);

                    if Pos('Diretório', nomePonte) <> 0 then
                        begin
                            n := Pos('Diretório', nomePonte);
                            delete(nomePonte, n-1, length(nomePonte));
                            _ChDir (nomePonte);
                        end
                    else
                    if Pos('..', nomePonte) <> 0 then
                        begin
                            sintetiza('Voltando diretório.');
                            if not voltarDir then
                                begin
                                    navegando := false;
                                    result := 'SP'; //Saindo da ponte
                                end;
                        end
                    else
                        begin
                            navegando := false; {Selecionaram um arquivo em vez de diretorio}
                            result := 'AS'; //Arquivo Selecionado
                        end;
                end
            else
            if n = -2 then
                begin
                    limpaBaixo(WhereY);
                    TextBackground(BLACK);
                    executaOpcao(opcao, nomePonte, 'D')
                end
            else
                begin
                    navegando := false;
                    result := 'SP'
                end;

            recuperaTelaArq;
        end;
end;

{----------------------------------------------------------------------}
{        processo de escolha da ponte e validação da existencia        }
{                       no arquivo pontes.ini                          }
{----------------------------------------------------------------------}

function SelecionarPonte(var nomePonte: string; var tipoDado: DataType): boolean;
var
    atalho: Char;
    item: integer;
begin
    Result := false;
    tipoDado := Nada;
    atalho := ' ';

    mensagem('EPNOMARQ', 1); {Informe o nome da ponte ou use as setas para selecionar }
    if nomePonte = '' then
        atalho := sintEditaCampo(nomePonte, wherex, wherey, 255, 80, true);

    if atalho = ESC then
        begin
            mensagem ('EPDESIST', 1) {Desistiu}
            exit;
        end;

    if nomePonte <> '' then
        if ponteExiste(nomePonte) then
            begin
                atalhoRapido := true;
                if salvaDadosPonte(nomePonte) then
                    Result := true
                else
                    sintWriteLn('Alguns parâmetros da ponte estão vazios. Consulte o PonteVox');
            end;
    else
        begin
            folhear(item);
            
            if item <> 0 then
                if ERRO = ERRO_PTINCORRETA then
                    sintWriteLn('Alguns parâmetros da ponte estão vazios. Consulte o PonteVox');
                else
                    begin
                        tipoDado := Diretorio;
                        Result := true;
                    end;
        end;
end;

{----------------------------------------------------------------------}
{           Processamento para inicialização do ediponte               }
{----------------------------------------------------------------------}

procedure processar;
var
   tipoPonte, dadoEscolhido, lendoAcao: string;
   tipoDado: DataType;
   opcao: char;
begin
    tipoPonte := '';
    nomePonte := '';

    if paramCount <> 0 then   // provisório, prover depois rotina de tratamento de parâmetros
        nomePonte := paramStr(1);

   while SelecionarPonte(nomePonte, tipoDado) do
       begin
           inicPonte;

           if inicializaPonteSelecionada(nomePonte) then
               begin
                   if atalhoRapido then
                       tipoDado := existeArqOuDir(nomePonte);

                   case tipoDado of
                       'D': begin
                           repeat
                               limpaBaixo(3);
                               tituloJanela ('EDIPONTE');
                               sintWriteLn('Buscando arquivos e diretórios'); //adicionar mensagem

                               lendoAcao := lendoRota(nomePonte);
                               if lendoAcao = 'SP' then
                                   begin
                                       mensagem('EPSAIRPNT', 1); {Você saiu da ponte. }
                                       opcao := ESC;
                                   end
                               else
                                   begin
                                       dadoEscolhido := nomePonte;
                                       executaOpcao(opcao, dadoEscolhido, 'A')
                                   end;
                           until opcao = ESC;
                       end;

                       'A': begin
                           dadoEscolhido := nomePonte;
                           executaOpcao(opcao, dadoEscolhido, tipoDado);
                       end;
                   end;
               end
           else
               begin
                   sintWriteLn('Ponte ' + tipoPonte + ' não foi inicializada corretamente, tente mais tarde.');
                   fecharPonte;
               end;


           closePonte;
           mensagem ('EPOUTPON', 0);  {'Deseja abrir outra ponte? '}
           if popupMenuPorLetra('SN') = 'N' then
               break
           else
               begin
                   limpaBaixo(3);
                   nomePonte := '';
               end;
       end;
end;

end.
