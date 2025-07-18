# MySQL Master-Slave com Docker

## Sumário
- [Visão Geral](#visão-geral)
- [Pré-requisitos](#pré-requisitos)
- [Inicialização do Ambiente](#inicialização-do-ambiente)
- [Configuração da Replicação](#configuração-da-replicação)
- [Comandos Úteis de Validação](#comandos-úteis-de-validação)
  - [Acessar as Instâncias](#acessar-as-instâncias)
  - [Validar Bancos e Tabelas](#validar-bancos-e-tabelas)
  - [Validar Replicação](#validar-replicação)
- [Resolução de Problemas](#resolução-de-problemas)
- [Referências](#referências)

---

## Visão Geral

Este projeto provisiona dois containers MySQL (master e slave) usando Docker Compose, com replicação configurada via script. As variáveis sensíveis estão isoladas em um arquivo `.env`.

---

## Pré-requisitos

- Docker e Docker Compose instalados
- Bash disponível no host

---

## Inicialização do Ambiente

1. **Configure o arquivo `.env` na raiz do projeto:**
   ```env
   MYSQL_ROOT_PASSWORD=sua_senha_segura
   MYSQL_DATABASE=seu_banco
   MYSQL_USER=seu_usuario
   MYSQL_PASSWORD=sua_senha_segura
   REPL_USER=usuario_replicacao
   REPL_PASSWORD=senha_replicacao
   ```

2. **Suba os containers:**
   ```sh
   docker compose up -d
   ```

3. **Execute o script de configuração da replicação:**
   ```sh
   ./setup-replica.sh
   ```

---

## Configuração da Replicação

O script `setup-replica.sh`:
- Cria o usuário de replicação no master
- Captura o status do binlog do master
- Aplica a configuração no slave
- Exibe logs detalhados em `/tmp/replica-setup.log`

---

## Comandos Úteis de Validação

### Acessar as Instâncias

**Master:**
```sh
docker exec -it mysql-master mysql -uroot -p$MYSQL_ROOT_PASSWORD
```

**Slave:**
```sh
docker exec -it mysql-slave mysql -uroot -p$MYSQL_ROOT_PASSWORD
```

### Validar Bancos e Tabelas

**Listar bancos:**
```sql
SHOW DATABASES;
```

**Listar tabelas em um banco:**
```sql
USE mydb;
SHOW TABLES;
```

**Consultar dados de uma tabela:**
```sql
SELECT * FROM mydb.replica_test;
```

### Validar Replicação

**No slave, verificar status da replicação:**
```sh
docker exec mysql-slave mysql -uroot -prootpass -e "SHOW SLAVE STATUS\G"
```
- Os campos importantes são:
  - `Slave_IO_Running: Yes`
  - `Slave_SQL_Running: Yes`
  - `Seconds_Behind_Master: 0`
  - `Last_IO_Error:` (deve estar vazio)
  - `Last_SQL_Error:` (deve estar vazio)

**No master, ver conexões de replicação:**
```sh
docker exec mysql-master mysql -uroot -prootpass -e "SHOW PROCESSLIST\G"
```
- Procure por linhas com `Command: Binlog Dump` (indica conexão de replicação ativa).

**Testar replicação criando tabela e dados no master:**
```sh
docker exec mysql-master mysql -uroot -prootpass -e "CREATE TABLE IF NOT EXISTS mydb.replica_test (id INT PRIMARY KEY, valor VARCHAR(100)); INSERT INTO mydb.replica_test VALUES (1, 'A'), (2, 'B'), (3, 'C'), (4, 'D'), (5, 'E');"
```
Depois, no slave:
```sh
docker exec mysql-slave mysql -uroot -prootpass -e "SELECT * FROM mydb.replica_test;"
```
- Os registros devem aparecer no slave.

---

## Resolução de Problemas

- **Replicação não ativa:**  
  Verifique o status com `SHOW SLAVE STATUS\G` e analise os campos de erro.
- **Acesso negado:**  
  Confirme permissões do usuário e se o host está correto.
- **Script não executa:**  
  Veja logs em `/tmp/replica-setup.log` e valide se o Docker está rodando.

---

## Referências

- [Documentação Oficial MySQL 8.4 - Replicação](https://dev.mysql.com/doc/refman/8.4/en/replication-administration-status.html)
- [Comandos Docker Compose](https://docs.docker.com/compose/)
- [Como criar um README eficiente](https://github.com/Tinymrsb/READMEhowto)

---

> Documentação criada seguindo boas práticas de Markdown e organização sugeridas pela comunidade open source [[1]](https://github.com/Tinymrsb/READMEhowto) [[2]](https://docs.github.com/en/get-started/writing-on-github/getting-started-with-writing-and-formatting-on-github/basic-writing-and-formatting-syntax).
