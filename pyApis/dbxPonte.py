import dropbox, sys, os

token = None

def access_token():
    global token
    token = dropbox.Dropbox('6m97rPtmSgAAAAAAAAAANkC4q_VO1s9bI2niEY0GDNWeTg-N3kKd_iKFypsxUuql')
    try:
        token.users_get_current_account()
        print('200')
    except dropbox.exceptions.AuthError as err:
        raise StandardError("ERROR: 500")

def listar_arq():
    global token
    rota = input('rota: ').lower()
    if(rota == 'raiz'):
        rota = ''

    for entry in token.files_list_folder(rota).entries:
        name = ""
        
        if(type(entry) is dropbox.files.FolderMetadata):
            name = '{} Diretório'.format(entry.name)
        else:
            name = entry.name

        if(entry.sharing_info is not None):
            name = '{} *'.format(name)

        print(name)

def detalhe_arq():
    global token

    arquivo = input('Arquivo: ')
    metadados = token.files_get_metadata(path=arquivo, include_media_info=True, include_has_explicit_shared_members=True)
    print(metadados)

def enviar_arq():
    global token

    rotaArq = input("rota arquivo: ")
    nomeArq = input("Nome arquivos: ")

    try:
        file_path = os.path.join(rotaArq, nomeArq)

        with open(file_path, "rb") as f:
                token.files_upload(f.read(), "/{}".format(nomeArq))
    except Exception as err:
        print("Failed to upload %s\n%s" % (nomeArq, err))

def baixar_arq():
    global token

    rotaLocal = input('pasta local: ')
    rotaArq = input('arquivo: ')

    try:
        file_path = os.path.join(rotaLocal, rotaArq)
        token.files_download_to_file(file_path, rotaArq)
        print(200)
    except Exception as err:
        print("Failed to download %s\n%s" % (rotaArq, err))

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
        print("Failed to download %s\n%s" % (rotaPasta, err))

def main():
    processando = True;

    while(processando):
        opcao = input().upper()

        if(opcao == 'LOGIN'):
            access_token()
        elif(opcao == 'ARQUIVOS'):
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
        elif(opcao == 'SAIR' or opcao == 'TERMINAR'):
            processando = False


    access_token()

if __name__ == '__main__':
    main()
