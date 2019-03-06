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

    print(rota)
    for entry in token.files_list_folder(rota).entries:
        if(type(entry) is dropbox.files.FolderMetadata):
            print('{} Diretório'.format(entry.name))
        else:
            print(entry.name)
        
def detalhe_arq():
    global token

    arquivo = input('Arquivo: ')
    metadados = token.files_get_metadata(path=arquivo, include_media_info=True)
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
        elif(opcao == 'SAIR' or opcao == 'TERMINAR'):
            processando = False
            
    
    access_token()

if __name__ == '__main__':
    main()
