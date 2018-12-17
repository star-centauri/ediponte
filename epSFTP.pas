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

function executarSFTP (ponte: TPonte): boolean;

implementation

function executarSFTP (ponte: TPonte): boolean;
begin
    connect := ponte.Conta + '@' + ponte.Servidor;
    app := 'psftp.exe ' + connect;
end;

end.
