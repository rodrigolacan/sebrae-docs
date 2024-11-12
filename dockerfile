# Use uma imagem base Python
FROM python:3.9-slim

# Defina o diretório de trabalho
WORKDIR /app

# Instale o MkDocs e o tema Material
RUN pip install mkdocs mkdocs-material

# Copie os arquivos do projeto MkDocs para o diretório de trabalho
COPY . /app

# Exponha a porta padrão do MkDocs
EXPOSE 8000

# Comando para iniciar o MkDocs
CMD ["mkdocs", "serve", "--dev-addr=0.0.0.0:8000"]
