{-------------------------------------------------------------}
{
{    Editor de arquivos para pontes
{
{    Autor: Bruna de Lima
{
{    Em 22/08/2018
{
{-------------------------------------------------------------}

program ediponte;

uses
  dvcrt,
  dvWin,
  dvform,
  epMsg,
  epvars,
  epProcessa,
  Windows,
  sysUtils;

{----------------------------------------------------------------------}
{                         Finaliza programa                            }
{----------------------------------------------------------------------}

procedure finaliza;
begin
   mensagem ('EPFIM', 1);  {Fim do ediponte}
   sintFim;
end;

{----------------------------------------------------------------------}
{              Inicialização da janela do PonteEdVox                   }
{----------------------------------------------------------------------}

procedure inicializa;
begin
    clrscr;
    tituloJanela ('EDIPONTE');

    ambiente := sintAmbiente('EDIPONTE', 'DIREDIPONTE');
    if ambiente = '' then
        ambiente := sintAmbiente('DOSVOX', 'PGMDOSVOX') + '\som\ediponte';
    sintinic (0, ambiente);

    textBackground (BLUE);
    mensagem ('EPTITULO', 0);  {'PonteVox'}
    sintWriteln ('' + VERSAO);
    textBackground (BLACK);
    writeln;

    nomePonte := '';
end;

begin
   inicializa;
   processar;
   finaliza;
end.

