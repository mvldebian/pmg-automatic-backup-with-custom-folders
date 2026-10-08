#!/bin/bash
# Script de Backup PMG
# Por Marcelo Leães - marcelo@spamcop.com.br

# --- CONFIGURAÇÕES ---
EMAIL_DESTINO="email a ser notificado"
EMAIL_REMETENTE="email de quem está enviando"
DIRETORIOS_EXTRAS="/scripts/ /var/lib/pmg/templates/spamreport-custom.tt /etc/pmg/templates/ /etc/mail/spamassassin/ /etc/postfix/"
RETENCAO_DIAS="7"

# --- VARIÁVEIS DO SISTEMA ---
DATA_FORMATADA=$(date +'%d/%m/%Y %H:%M:%S')
DATA_ARQUIVO=$(date +'%Y%m%d_%H%M%S')
PASTA_BACKUP="/var/lib/pmg/backup"
HOSTNAME_SISTEMA=$(hostname -f)

# 1. Executa o backup nativo do PMG
echo "Iniciando backup nativo do PMG..."
NATIVO_LOG=$(pmgbackup backup 2>&1)
STATUS_NATIVO=$?

# Encontra o último arquivo .tgz nativo gerado nos últimos 5 minutos
ARQUIVO_NATIVO=$(find "$PASTA_BACKUP" -name "pmg-backup_*.tgz" -mmin -5 -printf "%f\n" | head -n 1)

# 2. Compacta diretórios adicionais
echo "Compactando diretórios adicionais..."
ARQUIVO_EXTRAS="pmg-custom_${DATA_ARQUIVO}.tar.gz"
EXTRAS_LOG=$(tar -czf "${PASTA_BACKUP}/${ARQUIVO_EXTRAS}" $DIRETORIOS_EXTRAS 2>&1)
STATUS_EXTRAS=$?

# 3. Rotina de Retenção
echo "Removendo backups com mais de ${RETENCAO_DIAS} dias..."
ARG_DIAS="+${RETENCAO_DIAS}"

find "$PASTA_BACKUP" -name "pmg-backup_*.tgz" -mtime "$ARG_DIAS" -type f -delete 2>/dev/null
find "$PASTA_BACKUP" -name "pmg-custom_*.tar.gz" -mtime "$ARG_DIAS" -type f -delete 2>/dev/null

# 4. Avalia o status geral para o e-mail
if [ $STATUS_NATIVO -eq 0 ] && [ $STATUS_EXTRAS -eq 0 ]; then
    STATUS_GERAL="Sucesso"
    COR_STATUS="#2ec4b6" # Verde
else
    STATUS_GERAL="Com Falhas"
    COR_STATUS="#e71d36" # Vermelho
fi

# 5. Envia o E-mail com Layout HTML utilizando o comando mail
cat <<EOF | mail -s "PMG BACKUP - $HOSTNAME_SISTEMA ($STATUS_GERAL)" \
-a "From: $EMAIL_REMETENTE" \
-a "MIME-Version: 1.0" \
-a "Content-Type: text/html; charset=utf-8" \
"$EMAIL_DESTINO"
<html>
<head>
  <style>
    body { font-family: Arial, sans-serif; background-color: #f4f4f9; color: #333; margin: 0; padding: 20px; }
    .container { max-width: 600px; background: #ffffff; padding: 25px; border-radius: 8px; border-top: 5px solid ${COR_STATUS}; box-shadow: 0 4px 6px rgba(0,0,0,0.05); }
    h2 { color: #222; margin-top: 0; }
    .status-badge { display: inline-block; padding: 6px 12px; font-weight: bold; color: #fff; background-color: ${COR_STATUS}; border-radius: 4px; font-size: 14px; margin-bottom: 20px; }
    .info-table { width: 100%; border-collapse: collapse; margin-top: 15px; }
    .info-table td { padding: 10px; border-bottom: 1px solid #eee; font-size: 14px; }
    .info-table td.label { font-weight: bold; color: #666; width: 35%; }
    .footer { margin-top: 25px; font-size: 11px; color: #999; text-align: center; border-top: 1px solid #eee; padding-top: 15px; }
  </style>
</head>
<body>
  <div class='container'>
    <div class='status-badge'>Status Geral: ${STATUS_GERAL}</div>
    
    <table class='info-table'>
      <tr><td class='label'>Servidor:</td><td>${HOSTNAME_SISTEMA}</td></tr>
      <tr><td class='label'>Data e Hora:</td><td>${DATA_FORMATADA}</td></tr>
      <tr><td class='label'>Backup Nativo:</td><td>${ARQUIVO_NATIVO:-Não gerado}</td></tr>
      <tr><td class='label'>Backup Customizado:</td><td>${ARQUIVO_EXTRAS}</td></tr>
      <tr><td class='label'>Diretórios Extras:</td><td><small>${DIRETORIOS_EXTRAS}</small></td></tr>
      <tr><td class='label'>Retenção Aplicada:</td><td>${RETENCAO_DIAS} dias (arquivos antigos removidos)</td></tr>
    </table>
    
    <div class='footer'>
      Este e um e-mail automatico gerado pelo Proxmox Mail Gateway.<br>Diretório de destino local: <code>${PASTA_BACKUP}</code>
    </div>
  </div>
</body>
</html>
EOF

