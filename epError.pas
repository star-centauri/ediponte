unit epError;

interface
uses
  epvars;

const
     CRLF = #$0d + #$0a;
     ERRO_CONEXAO = 'Erro de conexao';
     ERRO_HTTP = 'Erro no servidor';
     ERRO_ESCRITA = 'Erro de escrita no arquivo';
     ERRO_DIG = 'Erro de digitação';
     ERRO_PNC = 'Erro ponte não foi criada';
     ERRO_TIMEOUT = 'Tempo esgotou';
     ERRO_CONTA = 'Login ou senha incorreto';
     ERRO_PORTA = 'Erro escolha porta';
     ERRO_REMOTO = 'Servidor remoto não aceitou o modo passivo';
     ERRO_ROTAVAZIA = 'Não existe caminho';
     ERRO_PTINCORRETA = 'Erro criação da ponte';
     ERRO_NEXISDIR = 'Diretório não existe';
     ERRO_NEXISARQ = 'Arquivo não existe';
     ERRO_OPCINV = 'Opção invalida';
     ERRO_ACESSTERM = 'Terminado acesso do host';

function tipoDeErro: string;

implementation

{----------------------------------------------------------------------}
{           retorna o valor da variavél erro e o seta                  }
{----------------------------------------------------------------------}

function tipoDeErro: string;
begin
    result := ERRO;
    ERRO := 'ND';
end;

begin
    ERRO := 'ND';
end.
