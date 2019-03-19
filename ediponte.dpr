{-------------------------------------------------------------}
{
{    Sistema para acessar as novas tecnologias da WEB
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
    procedure iniciarAmbiente;
    begin
        ambiente := sintAmbiente('EDIPONTE', 'DIREDIPONTE');
        if ambiente = '' then
            ambiente := sintAmbiente('DOSVOX', 'PGMDOSVOX') + '\som\ediponte';
        sintinic (0, ambiente);
    end;

    procedure DesenharTitulo;
    begin
    textColor (WHITE);
    TextBackground(Blue);

    writeln (' ______   _____    __   ______   _____   _    _   ______   ______ ');
    writeln ('|   ___| |  _  |  |  | |   _  | |  _  | |  |_| | |_    _| |   ___|');
    writeln ('|  |___  | | |  | |  | |  |_| | | | | | |      |   |  |   |  |___ ');
    writeln ('|   ___| | |_|  | |  | |   ___| | |_| | |  _   |   |  |   |   ___|');
    writeln ('|  |___  |      | |  | |  |     |     | | | |  |   |  |   |  |___ ');
    writeln ('|______| |_____|  |__| |__|     |_____| |_| |__|   |__|   |______|');

    mensagem('EPTITULO', 0); {'EDIPONTE'}
    sintWriteln(VERSAO);
    textBackground(BLACK);
    writeln;
    end;

begin
    clrscr;
    tituloJanela ('EDIPONTE Versão ' + VERSAO);
    iniciarAmbiente;
    DesenharTitulo;

    nomePonte := '';
end;

begin
   inicializa;
   processar;
   finaliza;
end.

