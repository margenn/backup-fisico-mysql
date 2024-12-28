#!/bin/bash

#CONFIGURE OS PARAMETROS AQUI
MYSQL_DATA_DIR="/usr/local/mysql8.0/data"
BACKUP_DIR="/home/ma/Desktop/db-backup/backups_fisicos"
BACKUPS_PARA_RETER=3

#FUNCOES
echored() { echo -e "\e[31m$1\e[0m"; }
echogreen() { echo -e "\e[32m$1\e[0m"; }
echoyellow() { echo -e "\e[33m$1\e[0m"; }
echoblue() { echo -e "\e[34m$1\e[0m"; }
echomagenta() { echo -e "\e[35m$1\e[0m"; }
echocian() { echo -e "\e[36m$1\e[0m"; }
remover_barra_final() { echo $(echo "$1" | sed 's|/$||'); }

#preparação das variáveis
DATE=$(date +"%y%m%d_%H%M%S")   # Data e hora para nomear o backup
SCRIPT_PATH=$(dirname "$(realpath "$0")")
MYSQL_DATA_DIR=$(remover_barra_final $MYSQL_DATA_DIR)
BACKUP_DIR_DATE=$(remover_barra_final $BACKUP_DIR)/$DATE
LOG_DIR="$SCRIPT_PATH/logs"
LOG_FILE="backup_fisico_$DATE.log"
STATUS_INICIAL=$(systemctl is-active mysql8.0.service)
ERR_STATUS=0

clear

ligar_log() {
    #grava uma cópia das mensagens deste script para um arquivo de log
    mkdir -p "$LOG_DIR"; touch "$LOG_DIR/$LOG_FILE"; exec > >(tee -a "$LOG_DIR/$LOG_FILE") 2>&1
}

listar_variaveis() {
    echo; echocian "VARIÁVEIS ENVOLVIDAS NO BACKUP:"
    vars=(MYSQL_DATA_DIR BACKUP_DIR DATE BACKUPS_PARA_RETER SCRIPT_PATH MYSQL_DATA_DIR \
            BACKUP_DIR_DATE LOG_DIR LOG_FILE BACKUPS_PARA_RETER STATUS_INICIAL)
    for var in "${vars[@]}"; do echo "$var = ${!var}"; done
}

parar_mysql() {
    echo; echocian "PARANDO O SERVIÇO MYSQL 8.0 ..."
    if [ $STATUS_INICIAL = "active" ]; then
        systemctl stop mysql8.0.service
        if [ $? -eq 0 ]; then echogreen "Serviço MySQL 8.0 parado com sucesso."
        else echored "Erro ao parar o serviço MySQL 8.0."; exit 1
        fi
    else
        echoyellow "Serviço MySQL 8.0 já estava parado."
    fi
}

listar_arquivos() {
    echo; echocian "LISTA DOS ARQUIVOS A SEREM BACKUPEADOS:"
    ls -RalF --group-directories-first "$MYSQL_DATA_DIR"
}

copiar_arquivos() {
    echo; echocian "INICIANDO CÓPIA DOS ARQUIVOS DE DADOS"
    mkdir -p "$BACKUP_DIR_DATE";
    sleep 1
    rsync -av --delete --exclude="mysql.sock" "$MYSQL_DATA_DIR/" "$BACKUP_DIR_DATE/"
    if [ $? -eq 0 ]; then echogreen "Pasta $MYSQL_DATA_DIR copiada para $BACKUP_DIR_DATE/"
    else ERR_STATUS=1; echored "Erro ao copiar arquivos de dados."
    fi
}

iniciar_mysql() {
    echo; echocian "RE-INICIANDO O SERVIÇO MYSQL 8.0 ..."
    if [ $STATUS_INICIAL = "active" ]; then
        systemctl start mysql8.0.service
        if [ $? -eq 0 ]; then echogreen "Serviço MySQL iniciado com sucesso."
        else echored "Erro ao iniciar o serviço MySQL."; exit 1
        fi
    else
        echoyellow "Serviço MySQL 8.0 já estava parado antes do backup iniciar. Desnecessário reiniciar."
    fi
}

rotacionar_pastas_backup() {
    echo; echocian "ROTACIONANDO PASTAS BACKUP"
    pastas=$(ls $BACKUP_DIR 2>/dev/null)
    if [ -n "$pastas" ]; then
        IFS=$'\n' read -rd '' -a arr_pastas <<< "$pastas"
        total_pastas=${#arr_pastas[@]}
        if [ "$total_pastas" -gt $BACKUPS_PARA_RETER ]; then
            for pasta in "${arr_pastas[@]:0:$total_pastas-$BACKUPS_PARA_RETER}"; do
                echo "Removendo backup antigo, pasta: $pasta"
                rm -rf "$BACKUP_DIR/$pasta"
            done
        else
            echoyellow "Não há mais de $BACKUPS_PARA_RETER pastas para remover."
        fi
    else
        echoyellow "Nenhuma pasta de backup foi encontrada."
    fi
}

rotacionar_logs() {
    echo; echocian "ROTACIONANDO LOGS"
    arquivos=$(ls $LOG_DIR | grep -P 'backup_fisico_\d+_\d+\.log')
    if [ -n "$arquivos" ]; then
        IFS=$'\n' read -rd '' -a arr_logs <<< "$arquivos"
        total_logs=${#arr_logs[@]}
        if [ "$total_logs" -gt $BACKUPS_PARA_RETER ]; then
            for arquivo in "${arr_logs[@]:0:$total_logs-$BACKUPS_PARA_RETER}"; do
                echo "Removendo arquivo de log: $arquivo"
                rm -f "$LOG_DIR/$arquivo"
            done
        else
            echoyellow "Não há mais de $BACKUPS_PARA_RETER arquivos para remover."
        fi
    else
        echoyellow "Nenhum arquivo encontrado no formato backup_fisico_*.log."
    fi
}

main() {
    echo; echocian "INICIANDO O BACKUP FÍSICO DO MYSQL 8.0 ..."
    ligar_log
    listar_variaveis
    parar_mysql
    listar_arquivos
    copiar_arquivos
    iniciar_mysql
    if [ $ERR_STATUS -eq 0 ]; then
        rotacionar_pastas_backup
        rotacionar_logs
        echo; echogreen "BACKUP FÍSICO REALIZADO COM SUCESSO."; exit 0
    else
        echo; echored "BACKUP FÍSICO REALIZADO COM ERRO."; exit 1
    fi
}

main
