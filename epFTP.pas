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
  
function executarFTP (ponte: TPonte): string;

implementation

function executarFTP (ponte: TPonte): string;
begin
    Result := 'C:\Windows\System32\ftp.exe ' + ponte.Servidor;
end;

end.
