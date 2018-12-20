unit epError;

interface
uses
  epvars;

const
     CRLF = #$0d + #$0a;
     ERRO_CONEXAO = 'Erro de conexao';
     ERRO_HTTP = 'Erro no servidor';
     ERRO_ESCRITA = 'Erro de escrita no arquivo';
     ERRO_DIG = 'Erro de digita��o';
     ERRO_PNC = 'Erro ponte n�o foi criada';
     ERRO_TIMEOUT = 'Tempo esgotou';
     ERRO_CONTA = 'Login ou senha incorreto';
     ERRO_PORTA = 'Erro escolha porta';
     ERRO_REMOTO = 'Servidor remoto n�o aceitou o modo passivo';
     ERRO_ROTAVAZIA = 'N�o existe caminho';
     ERRO_PTINCORRETA = 'Erro cria��o da ponte';
     ERRO_NEXISDIR = 'Diret�rio n�o existe';
     ERRO_NEXISARQ = 'Arquivo n�o existe';
     ERRO_OPCINV = 'Op��o invalida';
     ERRO_ACESSTERM = 'Terminado acesso do host';

function tipoDeErro: string;

implementation

{----------------------------------------------------------------------}
{           retorna o valor da variav�l erro e o seta                  }
{----------------------------------------------------------------------}

function tipoDeErro: string;
begin
    result := ERRO;
    ERRO := 'ND';
end;

begin
    ERRO := 'ND';
end.
