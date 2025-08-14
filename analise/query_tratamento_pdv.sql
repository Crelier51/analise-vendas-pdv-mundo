!pip install --upgrade google-colab
# Quary beta inclusão visualização dos dados

import pandas as pd
import unicodedata
import os
# Removendo pydrive, pois usaremos google-api-python-client
from google.colab import drive, files

# Novas importações para interação com Google Drive API (recomendado)
from google.colab import auth
from googleapiclient.discovery import build
from googleapiclient.http import MediaInMemoryUpload # Para fazer upload a partir da memória
from io import StringIO # Para tratar o CSV como um arquivo na memória

# --- Função auxiliar para remover acentos ---
def remover_acentos(texto):
    if isinstance(texto, str):
        texto = unicodedata.normalize('NFD', texto)
        texto = texto.encode('ascii', 'ignore').decode('utf-8')
    return texto

# --- Etapa 1: Montar o Google Drive e Autenticar o usuário do Colab ---
drive.mount('/content/drive')

# Autenticação para a Google API client (usando as credenciais do Colab)
# Este é o método mais robusto e recomendado para o Colab.
auth.authenticate_user()
# Constrói o serviço da Drive API v3
drive_service = build('drive', 'v3')


# --- Etapa 2: Upload manual do Excel bruto ---
print("Por favor, faça o upload do arquivo Excel bruto:")
uploaded = files.upload()
nome_arquivo = list(uploaded.keys())[0]

# --- Etapa 3: Leitura e preparação inicial ---
df = pd.read_excel(nome_arquivo)
df.columns = df.columns.str.strip()
df.fillna('', inplace=True)

# --- Etapa 4: Processamento de colunas binárias e quantidades associadas ---
pares = [
    ('Tem Fixodent 21g?', 'qtd_21g'),
    ('Tem Fixodent 40g?', 'qtd_40g'),
    ('Tem Fixodent 68g?', 'qtd_68g'),
    ('Tem algum pack Fixodent?', 'qtd_pack'),
    ('Temos material extra em loja? (Bandeja, Clipstrip…)', 'qtd_merchandising')
]

for pergunta, nome_qtd in pares:
    if pergunta in df.columns:
        idx = df.columns.get_loc(pergunta)
        col_resp = df.columns[idx + 1]
        df[pergunta] = df[pergunta].astype(str).str.strip().str.lower().map(lambda x: 1 if x in ['sim', '1', 'true'] else 0)
        df[nome_qtd] = pd.to_numeric(df[col_resp], errors='coerce').fillna(0).astype(int)

# --- Etapa 5: Renomear colunas principais ---
renomear = {
    'Tem Fixodent 21g?': 'tem_21g',
    'Tem Fixodent 40g?': 'tem_40g',
    'Tem Fixodent 68g?': 'tem_68g',
    'Tem algum pack Fixodent?': 'tem_pack',
    'Temos material extra em loja? (Bandeja, Clipstrip…)': 'tem_merchandising',
    'Respondido por': 'promotor_original',
    'Respondido em': 'data_resposta',
    'Respondido às': 'hora_resposta',
    'PDV': 'endereco_pdv_original',
    'Cidade': 'cidade_original',
    'Bandeira': 'rede_original',
    'Canal': 'canal_original',
    'Questionário': 'produto_original',
    'Número de Frentes Fixodent?': 'frentes_fixodente',
    'Número de Frentes Concorrência?': 'frentes_concorrencia',
    'Fixodent está posicionado ao lado de Corega no segmento de Fixadores?': 'posicionado_ao_lado_corega',
    'O preço está visível?': 'preco_visivel',
    'Informe quais Packs Estão Presentes na Loja': 'tipos_pack_original'
}
df = df.rename(columns=renomear)

# --- Etapa 6: Padronização de textos e criação de colunas normalizadas ---
df['promotor'] = df['promotor_original'].astype(str).apply(lambda x: remover_acentos(x).lower())
df['endereco_pdv'] = df['endereco_pdv_original'].astype(str).apply(lambda x: remover_acentos(x).lower())
df['cidade'] = df['cidade_original'].astype(str).apply(lambda x: remover_acentos(x).lower())
df['rede'] = df['rede_original'].astype(str).apply(lambda x: remover_acentos(x).lower())
df['canal'] = df['canal_original'].astype(str).apply(lambda x: remover_acentos(x).lower())
df['produto'] = df['produto_original'].astype(str).apply(lambda x: remover_acentos(x).lower())
df['tipos_pack'] = df['tipos_pack_original'].astype(str).apply(lambda x: remover_acentos(x).lower())

# --- NOVO: Criar coluna de controle de acesso por e-mail do usuário ---
def mapear_email(pdv):
    # CORREÇÃO: Aplicar strip().lower() diretamente na variável 'pdv' que é a string
    pdv = pdv.strip().lower()
    if any(x in pdv for x in ['venancio', 'farmalife', 'drogasmil']):
        return 'almarepresentacao@gmail.com'
    elif 'pacheco' in pdv:
        return 'rafael_bellentani@hotmail.com'
    elif 'carrefour' in pdv:
        return 'a_definir'
    elif 'nossa drogaria' in pdv:
        return 'a_definir'
    else:
        return 'a_definir'

df['endereco_pdv_usuario'] = df['endereco_pdv'].apply(mapear_email)

# --- Etapa 7: Outras binárias simples ---
for col in ['posicionado_ao_lado_corega', 'preco_visivel']:
    if col in df.columns:
        df[col] = df[col].astype(str).str.strip().str.lower().map(lambda x: 1 if x in ['sim', '1', 'true'] else 0)

# --- Etapa 8: Datas e período ---
df['data_resposta'] = pd.to_datetime(df['data_resposta'], dayfirst=True, errors='coerce')

if df['data_resposta'].isnull().all():
    print("⚠️ Atenção: Nenhuma data válida foi detectada na coluna 'data_resposta'. Verifique o formato no Excel.")

df['periodo_valor'] = df['data_resposta'].dt.to_period('M').astype(str)
df['periodo_tipo'] = 'mensal'
df['metrica'] = ''
df['valor_metrica'] = ''

# --- Etapa 9: Garantir colunas finais para exportação ---
colunas_finais = [
    'promotor', 'promotor_original', 'data_resposta', 'hora_resposta',
    'endereco_pdv', 'endereco_pdv_original', 'cidade', 'cidade_original',
    'rede', 'rede_original', 'canal', 'canal_original',
    'produto', 'produto_original',
    'tem_21g', 'qtd_21g', 'tem_40g', 'qtd_40g',
    'tem_68g', 'qtd_68g', 'tem_pack', 'qtd_pack',
    'tipos_pack', 'tipos_pack_original',
    'frentes_fixodente', 'frentes_concorrencia', 'posicionado_ao_lado_corega',
    'preco_visivel', 'tem_merchandising', 'qtd_merchandising',
    'periodo_valor', 'periodo_tipo', 'metrica', 'valor_metrica',
    'endereco_pdv_usuario'
]

for col in colunas_finais:
    if col not in df.columns:
        df[col] = 0

df = df[colunas_finais]

# --- Etapa 10: Salvar/Atualizar no Google Drive usando google-api-python-client ---
pasta_looker_nome = 'looker'
file_name = 'fixodent_tratado.csv'

# 1. Encontrar a ID da pasta 'looker'
# Vamos usar o Drive API para procurar a pasta na raiz do 'Meu Drive'
folder_id = None
response = drive_service.files().list(
    q=f"name='{pasta_looker_nome}' and mimeType='application/vnd.google-apps.folder' and 'root' in parents and trashed=false",
    fields='files(id)'
).execute()
folders = response.get('files', [])

if folders:
    folder_id = folders[0]['id']
else:
    # Se a pasta não existir, criá-la
    folder_metadata = {
        'name': pasta_looker_nome,
        'mimeType': 'application/vnd.google-apps.folder',
        'parents': ['root'] # 'root' refere-se ao "Meu Drive"
    }
    folder = drive_service.files().create(body=folder_metadata, fields='id').execute()
    folder_id = folder.get('id')
    print(f"Pasta '{pasta_looker_nome}' criada no Google Drive com ID: {folder_id}")

# 2. Converter DataFrame para CSV em uma string na memória
csv_string = df.to_csv(index=False, encoding='utf-8-sig')

# 3. Preparar o corpo da mídia para upload
media_body = MediaInMemoryUpload(csv_string.encode('utf-8-sig'), mimetype='text/csv')

# 4. Procurar pelo arquivo 'fixodent_tratado.csv' dentro da pasta 'looker'
file_id = None
response = drive_service.files().list(
    q=f"name='{file_name}' and '{folder_id}' in parents and trashed=false",
    fields='files(id)'
).execute()
files_found = response.get('files', [])

if files_found:
    # Arquivo encontrado, vamos atualizá-lo
    file_id = files_found[0]['id']
    updated_file = drive_service.files().update(
        fileId=file_id,
        media_body=media_body
    ).execute()
    file_id = updated_file.get('id')
    print(f"\n✅ Arquivo '{file_name}' atualizado com sucesso no Google Drive (ID: {file_id}).")
else:
    # Arquivo não encontrado, vamos criá-lo na pasta 'looker'
    file_metadata = {
        'name': file_name,
        'parents': [folder_id], # A pasta onde o arquivo será criado
        'mimeType': 'text/csv'
    }
    created_file = drive_service.files().create(
        body=file_metadata,
        media_body=media_body,
        fields='id'
    ).execute()
    file_id = created_file.get('id')
    print(f"\n✅ Arquivo '{file_name}' criado com sucesso no Google Drive (ID: {file_id}).")

print(f"O ID final do arquivo 'fixodent_tratado.csv' no Google Drive é: {file_id}")
print(f"Agora, no Looker Studio, conecte-se a este arquivo usando o ID: {file_id}")
print("Se você já tinha ele conectado, ele deve atualizar automaticamente em breve.")