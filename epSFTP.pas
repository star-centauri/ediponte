unit epSFTP;

interface
uses
  dvcrt,
  dvwin,
  dvform,
  minireg,
  epError,
  epvars,
  epMsg,
  synacode,
  windows,
  sysUtils,
  Classes,
  strUtils;

function executarSFTP (ponte: TPonte): string;

implementation

{----------------------------------------------------------------------}
{                  Executa a inicialização do servidor                 }
{----------------------------------------------------------------------}

function executarSFTP (ponte: TPonte): string;
var
    connect: String;
begin
    connect := ponte.Conta + '@' + ponte.Servidor;
    Result := 'psftp.exe ' + connect;
end;

end.
