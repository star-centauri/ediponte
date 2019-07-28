import dropbox, sys, os, time
from dropbox import DropboxOAuth2FlowNoRedirect
from hurry.filesize import size, verbose
import webbrowser

token = None

def type_error(tag):
    if(tag.is_not_found()):
        print('404: arquivo/diretório não encontrado nesta rota ou não existe.')
    elif(tag.is_malformed_path()):
        print('405: O caminho fornecido não satisfaz o formato de caminho requerido.')
    elif(tag.is_not_file()):
        print('401: Estávamos esperando um arquivo, mas o caminho indicado refere-se a algo que não é um arquivo.')
    elif(tag.is_not_folder()):
        print('401: Estávamos esperando uma pasta, mas o caminho indicado refere-se a algo que não é uma pasta.')
    elif(tag.is_restricted_content()):
        print('403: O arquivo não pode ser transferido porque o conteúdo é restrito.')
    else:
        print('500: erro ao executar o comando')

def access_Oauth():
    global token

    auth_flow = DropboxOAuth2FlowNoRedirect('b84tcu1f1ctkwpw', '2rye81pkwjfuf85')
    authorize_url = auth_flow.start()
    webbrowser.open(authorize_url, new=2)
    auth_code = input("202: ").strip()
    
    try:
        oauth_result = auth_flow.finish(auth_code)
        print("200:success")
    except Exception as err:
        print('500: {}'.format(err))

    token = dropbox.Dropbox(oauth_result.access_token)

def access_token():
    global token
    token = dropbox.Dropbox('6m97rPtmSgAAAAAAAAAANkC4q_VO1s9bI2niEY0GDNWeTg-N3kKd_iKFypsxUuql')
    
    try:
        token.users_get_current_account()
        print('200: success')
    except Exception as err:
        print('500: {}'.format(err))

def listar_arq():
    global token
    rota = input('rota: ').lower()
    if(rota == 'raiz'):
        rota = ''

    listItems = []

    try:
        for entry in token.files_list_folder(rota).entries:
            name = ""

            if(type(entry) is dropbox.files.FolderMetadata):
                name = '{} Diretório'.format(entry.name)
            else:
                name = entry.name

            if(entry.sharing_info is not None):
                name = '{} (compartilhado)'.format(name)

            listItems.append(name)
        
        print("{}|".format("|".join(listItems)))
    except dropbox.exceptions.ApiError as error:
        print('500: {}'.format(error.user_message_text))

def detalhe_arq():
    global token
    arquivo = input('Arquivo: ')
    propriedades = ""

    try:
        res = token.files_get_metadata(path=arquivo, include_media_info=True, include_has_explicit_shared_members=True)
        if(type(res) is dropbox.files.FileMetadata):
            propriedades = 'Localização no Dropbox: {0}|Data e hora modificação: {1}|Tamanho: {2}|'.format(res.path_lower, res.server_modified.strftime("%m/%d/%Y %H:%M:%S"), size(res.size, system=verbose))

        if(res.sharing_info is not None):
            propriedades = '{0}ID compartilhamento: {1}|'.format(propriedades, res.sharing_info.shared_folder_id)

        print(propriedades)
    except dropbox.exceptions.ApiError as e:
        if(e.error.is_path()):
            type_error(e.error.get_path())

def enviar_arq():
    global token

    nomeArq = input('Nome arquivos: ')
    rotaLocal = input('Rota local: ')
    rotaRemota = input('Rota remota: ')

    try:
        file_path = os.path.join(rotaLocal, nomeArq)
        dest_path = os.path.join(rotaRemota, nomeArq)

        with open(file_path, "rb") as f:
            token.files_upload(f.read(), dest_path, mode=dropbox.files.WriteMode('overwrite', None), mute=True)

        print('200: enviado com sucesso.')
    except dropbox.exceptions.ApiError as e:
        if(e.error.is_path()):
            if(e.error.get_path()):
                print('203: Não é possível salvar o conteúdo carregado em um arquivo.')

def baixar_arq():
    global token

    rotaLocal = input('pasta local: ')
    rotaArq = input('arquivo: ')

    try:
        token.files_download_to_file(rotaLocal, rotaArq)
        print(200)
    except dropbox.exceptions.ApiError as e:
        if(e.error.is_path()):
            type_error(e.error.get_path())

def baixar_pasta_zip():
    global token

    rotaLocal = input('rota local: ')
    rotaPasta = input('pasta: ')

    try:
        file_path = os.path.join(rotaLocal, rotaPasta)
        token.files_download_zip_to_file("{}.zip".format(file_path), rotaPasta)
        print(200)
    except Exception as err:
        print("Failed to download %s\n%s" % (rotaPasta, err))

def mover_arq_ou_pasta():
    global token

    pastaAntiga = input('da pasta: ')
    novaPasta = input('para pasta: ')

    try:
        token.files_move(pastaAntiga, novaPasta)
        print(200)
    except Exception as err:
        print("Failed to download %s\n%s" % (rotaPasta, err))

def remover_arq_ou_pasta():
    global token

    nomeArqOuPasta = input('caminho: ')

    try:
        token.files_delete(nomeArqOuPasta)
        print(200)
    except Exception as err:
        print("Failed to download %s\n%s" % (rotaPasta, err))

def criar_pasta():
    global token

    nomePasta = input('nome nova pasta: ')

    try:
        token.files_create_folder(nomePasta)
        print(200)
    except Exception as err:
        print("500: {}".format(err))

def remover_contato():
    global token

    email = input("email: ")
    try:
        token.contacts_delete_manual_contacts_batch(email)
        print(200)
    except Exception as err:
        print("500: " + err)

def solicitar_permissao_dado():
    global token

    title = input("titulo: ")
    pasta_destino = input("pasta destino: ")

    try:
        token.file_requests_create(title, pasta_destino, deadline=None, open=True)
        print(200)
    except Exception as err:
        print('500: {}'.format(error.user_message_text))

def copiar_arq():
    global token

    de_caminho = input("Da pasta: ")
    para_caminho = input("Para pasta: ")

    try:
        token.files_copy(de_caminho, para_caminho, allow_shared_folder=False, autorename=False, allow_ownership_transfer=False)
        print(200)
    except Exception as err:
        print("Failed to download %s\n%s" % (rotaPasta, err))

def visualizar_arq():
    global token

    arquivo = input("arquivo: ")

    try:
        token.files_get_preview(arquivo, rev=None)
        print(200)
    except Exception as err:
        print('500: {}'.format(error.user_message_text))

def gerar_link_temporario():
    global token

    arquivo = input("arquivo: ")

    try:
        token.files_get_temporary_link(arquivo)
        print(200)
    except Exception as err:
        print('500: {}'.format(err.user_message_text))

def adicionar_membro_dado():
    global token

    arquivo = ("arquivo: ")
    membro = ("membro: ")
    mensagem = ("mensagem: ")

    try:
        token.fsharing_add_file_member(arquivo, membro, custom_message=mensagem, quiet=False, access_level=AccessLevel('viewer', None), add_message_as_comment=False)
        print(200)
    except Exception as err:
        print('500: {}'.format(err.user_message_text))

def visualizar_membros_arq():
    global token

    arquivo = input("arquivo compartilhado: ")
    try:
        token.sharing_list_file_members(arquivo, actions=None, include_inherited=True, limit=100)
        print(200)
    except Exception as err:
        print('500: {}'.format(err.user_message_text))

def espaco_conta():
    global token

    try:
        token.users_get_space_usage()
        print(200)
    except Exception as err:
        print('500: {}'.format(err))

def main():
    processando = True

    while(processando):
        opcao = input().upper()

        if(opcao == 'LOGIN'):
            access_token()
        elif(opcao == 'AUTH'):
            access_Oauth()
        elif(opcao == 'LISTAR'):
            listar_arq()
        elif(opcao == 'ENVIAR'):
            enviar_arq()
        elif(opcao == 'PROPRIEDADE'):
            detalhe_arq()
        elif(opcao == 'BAIXAR'):
            baixar_arq()
        elif(opcao == 'ZIP'):
            baixar_pasta_zip()
        elif(opcao == 'MOVER' or opcao == 'RENOMEAR'):
            mover_arq_ou_pasta()
        elif(opcao == 'EXCLUIR'):
            remover_arq_ou_pasta()
        elif(opcao == 'PASTA'):
            criar_pasta()
        elif(opcao == 'REMOVER CONTATO'):
            remover_contato()
        elif(opcao == 'SOLICITAR PERMISSAO'):
            solicitar_permissao_dado()
        elif(opcao == 'COPIAR'):
            copiar_arq()
        elif(opcao == 'VISUALIZAR'):
            visualizar_arq()
        elif(opcao == 'CRIAR'):
            criar_pasta()
        elif(opcao == 'LINK'):
            gerar_link_temporario()
        elif(opcao == 'ADICIONAR MEMBRO'):
            adicionar_membro_dado()
        elif(opcao == 'VISUALIZAR MEMBROS'):
            visualizar_membros_arq()
        elif(opcao == 'CONTA'):
            espaco_conta()
        elif(opcao == 'SAIR' or opcao == 'TERMINAR'):
            processando = False
        else:
            print('404: not found option')


if __name__ == '__main__':
    main()
