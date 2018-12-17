{-------------------------------------------------------------}
{
{    Editor de textos sonoro simplificado
{
{    Módulo de mensagens
{
{    Em 11/08/2018
{
{-------------------------------------------------------------}

unit epMsg;

interface

uses windows, dvcrt, dvwin, sysUtils;

procedure mensagem (nomeArq: string; nlf: integer);
procedure tituloJanela (s: string);
procedure naoImplem;

implementation

procedure mensagem (nomeArq: string; nlf: integer);
var i: integer;
    s: string;
begin
    if nomeArq = 'EPTITULO' then
        s := 'EDIPONTE v.'
    else
    if nomeArq = 'EPFIM' then
        s := 'Fim do ediponte'
    else
    if nomeArq = 'EPNOMARQ' then
        s := 'Informe o nome da ponte ou use as setas para selecionar '
    else
    if nomeArq = 'EPCANC' then
        s := 'Cancelado'
    else
    if nomeArq = 'EPARQNOV' then
        s := 'Arquivo novo'
    else
    if nomeArq = 'EPSEMMEM' then
        s := 'Memória esgotada'
    else
    if nomeArq = 'EPERRGRV' then
        s := 'Erro de gravacao'
    else
    if nomeArq = 'EPUSEF2' then
        s := 'Use control F2 para trocar o nome'
    else
    if nomeArq = 'EPARQGRV' then
        s := 'Arquivo baixado'
    else
    if nomeArq = 'EPCNFORD' then
        s := 'Aperte S para confirmar ordenação'
    else
    if nomeArq = 'EPTXTBUS' then
        s := 'Informe o texto buscado '
    else
    if nomeArq = 'EPAJU01' then
        s := 'As principais opções deste programa são'
    else
    if nomeArq = 'EPAJU02' then
        s := 'ENTER insere linha'
    else
    if nomeArq = 'EPAJU03' then
        s := 'F1  fala palavra'
    else
    if nomeArq = 'EPAJU04' then
        s := 'F2  grava'
    else
    if nomeArq = 'EPAJU05' then
        s := 'F3  informa linha atual'
    else
    if nomeArq = 'EPAJU06' then
        s := 'F4  controle da soletragem'
    else
    if nomeArq = 'EPAJU07' then
        s := 'F5  busca trecho'
    else
    if nomeArq = 'EPAJU08' then
        s := 'F6  ordena arquivo'
    else
    if nomeArq = 'EPAJU09' then
        s := 'F7  remove linha atual'
    else
    if nomeArq = 'EPAJU10' then
        s := 'F8  Informa hora'
    else
    if nomeArq = 'EPAJU11' then
        s := 'F9  ajuda'
    else
    if nomeArq = 'EPAJU12' then
        s := 'ESC termina'
    else
    if nomeArq = 'EPTENTER' then
        s := 'Tecle Enter'
    else
    if nomeArq = 'EPCNFFIM' then
        s := 'Confirma fim (s/n) ? '
    else
    if nomeArq = 'EPQUERGV' then
        s := 'No momento não é possível gravar o arquivo remotamente.'
    else
    if nomeArq = 'EPDESBAIX' then
        s := 'Deseja baixá-lo? '
    else
    if nomeArq = 'EPAPTF9' then
        s := 'Aperte F9 para ajuda'
    else
    if nomeArq = 'EPESPERE' then
        s := 'Espere'
    else
    if nomeArq = 'EPOK' then
        s := 'OK'
    else
    if nomeArq = 'EPNOVLIN' then
        s := 'Nova linha'
    else
    if nomeArq = 'EPLINHA' then
        s := 'Linha '
    else
    if nomeArq = 'EPNAOACH' then
        s := 'Não achou'
    else
    if nomeArq = 'EPLINREM' then
        s := 'Linha removida'
    else
    if nomeArq = 'EPBAIXA' then
        s := 'Deseja baixar no diretório atual? (s/n) '
    else
    if nomeArq = 'EPINV' then
        s := 'Opção inválida, tente novamente.'
    else
    if nomeArq = 'EPINVED' then
        s := 'Extensão do arquivo inválida para edição.'
    else
    if nomeArq = 'EPOUTOP' then
        s := 'Escolha outra opção'
    else
    if nomeArq = 'EPPONTNE' then
        s := 'Ponte não existe, deseja criar?'
    else
    if nomeArq = 'EPARQOP' then
        s := 'O que deseja fazer? '   
    else
    if nomeArq = 'EPSELDIR' then
        s := 'Informe um diretório, ou use as setas para preferidos'
    else
    if nomeArq = 'EPEDITAR' then
        s := 'E - Editar Arquivo'
    else
    if nomeArq = 'EPBAIXAR' then
        s := 'B - Baixar Arquivo'
    else
    if nomeArq = 'EPENVIAR' then
        s :=  'V - Enviar Arquivo'
    else
    if nomeArq = 'EPAPAGAR'then
        s :=  'A - Apagar Arquivo'
    else
    if nomeArq = 'EPPROPS' then
        s :=  'P - Propriedades do Arquivo'
    else
    if nomeArq = 'EPTERMINAR' then
        s :=  'ESC - terminar'
    else
    if nomeArq = 'EPFOLHOPC' then
        s :=  'Folheie com as setas e escolha sua opção'
    else
    if nomeArq = 'EPOUTPON' then
        s :=  'Deseja abrir outra ponte?'
    else
    if nomeArq = 'EPDESIST' then
        s := 'Desistiu'
    else
    if nomeArq = 'EPSAIRPNT' then
        s := 'Você saiu da ponte'

    else
        s := '--> Mensagem inválida: ' + nomeArq;

    if nlf >= 0 then
        write (s);
    for i := 1 to nlf do
        writeln;

    if existeArqSom (nomearq) then
        sintSom (nomearq)
    else
        sintetiza (s);
end;

{----------------------------------------------------------------------}
{                       Muda título da janela                          }
{----------------------------------------------------------------------}

procedure tituloJanela (s: string);
var
    nomeJan: array [0..144] of char;
begin
    strPcopy (nomeJan, 'Ediponte ' + s);
    setWindowText (crtWindow, nomeJan);
end;

{----------------------------------------------------------------------}
{                       Rotina não implementada
{----------------------------------------------------------------------}

procedure naoImplem;
begin
    sintWriteln ('Não implementado');
end;


end.
