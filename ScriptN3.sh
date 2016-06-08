#!/bin/bash
#===============================================================================    
# FATEC São Caetano
# Sistemas Operacionais - N3
#===============================================================================
# William Hanemann da Silva - william.hanemann@gmail.com
# Lucas de Paula - lucasdepaulags@gmail.com
# Kaio Cesar Ramos - kaio_cesar_ramos@hotmail.com
#===============================================================================
# Link para o script:
# (https://github.com/invenktive/gerenciador-processos-BASH/blob/master/ScriptN3.sh)
#===============================================================================
#
#                       Script Gerenciador de Processos v0.1.0
#
# Este script foi criado para facilitar o gerenciamento dos processos do linux
# Entre suas funcionalidades, encontram-se:
#   -Possibilidade de iniciar o Nmon e mantê-lo rodando até o momento em que o usuário desejar sair
#   -Listar os processos podendo-se escolher:
#      -Visualizar os processos de usuários específicos
#      -Escolher quais informações devem ser mostradas na listagem e sua ordem de vizualização
#      -Escolher como será sorteada a visualização
#   -Listar apenas processos em determinado estado
#   -Gerenciar vários processos específicos simultaneamente:
#      -Localizador de PIDs com função de selecionar automaticamente os PIDs encontrados
#      -Possibilidade de digitar os PIDs
#      -Escolher os PIDs a partir de uma lista
#      -Alterar prioridades dos processos
#      -Enviar sinais
#      -Trazê-los para Primeiro plano
#      -Enviá-los para Segundo Plano
#      -Visualizar informações sobre os processos selecionados
#      -Visualizar processos filhos dos selecionados e informações sobre eles
#      -Visualizar as threads dos processos escolhidos e informações sobre elas
#   -Iniciar novos processos com opções personalizadas:
#      -Escolher o caminho para o processo em um navegador de arquivos visual
#      -Utilizar argumentos personalizados para a inicialização do novo processo
#      -Ajustar a prioridade com que o processo será iniciado
#      -Escolher se deseja ou não aplicar permissões de execução ao arquivo
#         -Escolher quais permissões de execução deseja aplicar
#      -Decidir se o novo processo será lançado em primeiro ou segundo plano
#
# Obs.: O script deve ser executado com privilegios administrativos. (e.g. sudo, root)
#
#===============================================================================
#
# USO: 'sudo ./Script.sh'
# 
#=============================================================================== 

# Variaveis

tmpHeader=$(mktemp) # Cria arquivo temporário e armazena o caminho na variável tmpHeader.
tmpOutput=$(mktemp) # Idem, mas armazena na variável tmpOutput.
procGetColumns="user,pid,nlwp,pri,ni,pcpu,pmem,rss,vsz,stat,cmd" # Define estas colunas como padrão para a listagem de processos.
procSortColumns="pid" # Define esta coluna como padrão para classificar a listagem de processos.
procGetUsr="$USER" # Define este usuário como padrão para a listagem de processos.
procStateGrep='-' # Define '-' como escolha padrão para o filtro de estados de processos.
procInfoColumns="stat=Estado,nlwp=No.Threads,lwp=ThreadID,pri=Prioridade,ni=Nice,pcpu,pmem,rss=RAM,vsz=Mem.Total,user=Usuario,cmd=ComandoCompleto" # Define estas colunas como padrão para informações do processo.
procInfoSort="lwp" # Define esta coluna como padrão para classificar as informações do processo.

errorMsg(){
   clear
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Aviso' \
      --textbox '\nDevido a algum erro inesperado ou a propria escolha do usuario, a acao foi cancelada.\n\nRetornando ao menu anterior.' \
      0 0
   $backTo
}

procInfo(){ # Função: Informacoes sobre determinado(s) processos
   backTo=menuEditProc # Determina a função 'menuEditProc' (Menu "Editar processo Específico") como padrão para voltar.
   clear # Limpa a tela
   ps --header --lines 15 -o $procInfoColumns --sort $procInfoSort $getProc > $tmpOutput || errorMsg # Armazena as informações sobre o processo escolhido na variável $tmpOutput.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Informacoes do Processo' \
      --textbox $tmpOutput \
      0 0 || $backTo # Caixa de texto do Dialog exibindo as informações que foram gravadas em $tmpOutput. Caso retorne erro, volta para a função pré determinada.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

sigProc() { # Função: Enviar sinal ao processo
   backTo=menuEditProc # Determina a função 'menuEditProc' (Menu "Editar processo Específico") como padrão para voltar.
   clear # Limpa a tela
   kill -s \
      $(dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Enviar Interrupcao' \
         --menu '\nQual interrupção deseja enviar para os processos selecionados?' \
         0 0 0 \
         'HUP' 'Avisa que o tty vinculado fechou [-1]' \
         'INT' 'Terminar Processo (i.e. Crtl+C)[-2]' \
         'QUIT' 'Terminar processo e fazer dump do nucleo (i.e. Ctrl+\)[-3]' \
         'ABRT' 'Abortar [-6]' \
         'KILL' 'Terminar imediatamente. Nao pode ser ignorado. [-9]' \
         'TERM' 'Terminar o processo [-15]' \
         'CONT' 'Continuar processo "pausado" [-18]' \
         'STOP' '"Pausar" o processo [-19]' || $backTo) \
      -a $getProc || errorMsg
   # Acima: Menu em dialog para usuário escolher qual sinal enviar para o processo. E comando kill, que utiliza a escolha para enviá-lo.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

reniceProc(){ # Função: Alterar prioridade (renice)
   backTo=menuEditProc #Determina a função 'menuEditProc' (Menu "Editar processo Específico") como padrão para voltar.
   clear # Limpa a tela
   renice -n \
      $(dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Alterar Prioridade' \
         --rangebox '\nUtilize as teclas +/-/setas para ajustar a barra conforme a prioridade que deseja.\n\nLembre-se: quanto menor o numero, maior a prioridade' \
         0 0 -20 +20 0 || $backTo) \
      -p $getProc || errorMsg
   # Acima: Menu em dialog para usuário alterar a prioridade do processo. E comando renice, que utiliza a escolha para alterá-la.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

getProc(){ # Função: Escolher processo específico.
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   getProcChoice=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Escolher Processo' \
         --menu '\nDeseja inserir o PID do processo ou escolhe-lo em uma Lista? \n\nObs.: Para localizar o PID de um processo, selecione "Localizar"' \
         0 0 0 \
         Lista '' \
         PID '' \
         Localizar '' || $backTo)
      # Acima: Menu para o usuário escolher como deseja inserir o(s) PID(s) do(s) processo(s).
   case $getProcChoice in # Condição complementar ao menu acima que define o que fazer a cada escolha.
      Lista) getProc=$( \
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Escolher Processo' \
            --checklist 'Quais processos deseja gerenciar?' \
            0 0 0 \
            $(ps --no-header -o user,pid,comm | tr -s " "  | cut -d " " -f 2,3 | cat -E  | cut -d"$" -f 1- --output-delimiter " off " || errorMsg) || $backTo) ;;
      # Acima: Caso a escolha seja "Lista", mostra um menu com uma lista dos processos disponíveis.
      menuEditProc # Vai para o menu onde os processos escolhidos poderão ser gerenciados.
   PID) getProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Escolher Processo' \
         --inputbox 'Digite o PID. Para varios PIDs, separe-os utilizando espacos.\n\nAtencao para a digitacao correta!' \
         0 0 || $backTo) ;;
      # Acima: Caso a escolha seja "PID", o usuário insere, através do dialog, o(s) PID(s) que desejar.
      menuEditProc # Vai para o menu onde os processos escolhidos poderão ser gerenciados.
   Localizar) findPID=$( \
         ps -C \
            $(dialog \
               --backtitle 'Gerenciador de Processos' \
               --stdout \
               --title 'Localizador de PIDs' \
               --inputbox 'Digite o nome do processo' \
               0 0 || $backTo) \
            --no-header -o user,pid,cmd | tr -s " " | cut -d' ' -f2 | paste -sd' ' || errorMsg) \
         ; (dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Localizador de PIDs' \
            --yes-label 'Sim' \
            --no-label 'Nao' \
            --yesno "\nPIDs encontrados para este processo:\n\n$findPID\n\nDeseja utiliza-los no gerenciador?\n" \
            0 0 || $backTo) \
         ; getProc=$findPID ; menuEditProc;;
      # Acima: Caso a escolha seja "Localizar", o usuário insere, através do dialog, o nome do processo que procura; o comando ps lista os processos com este nome.
      # Utilizando a filtragem no comando ps, é extraida uma lista de PIDs que é formatada adequadamente para uso futuro.
   esac # Fim da condição.
   $backTo # Volta para a função pré-determinada.
} # Fim da função

menuCreateProc() { # Função: Escolher como iniciar um novo processo.
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela.
   pathNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Caminho' \
         --fselect '/' \
         20 60 || $backTo) 
      # Acima: Opção do dialog para escolher o caminho do processo que deverá ser iniciado.
   pathNewProcIsOk=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Caminho' \
         --yesno "Caminho para o processo:\n\n $pathNewProc \n\nEsta correto?" \
         0 0 || $backTo)
         
      # Acima: Confirmação do caminho do processo
   argsNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Argumentos' \
         --inputbox 'Digite os argumentos para a inicializacao do processo (e.g. -eLf, --help). Deixe em branco para "nenhum".' \
         0 0 || $backTo) 
      # Acima: Dialog onde usuário poderá inserir, opcionalmente, argumentos para a inicializacao do processo.
   niceNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar processo: Prioridade' \
         --rangebox '\nUtilize as teclas +/-/setas para ajustar a barra conforme a prioridade que deseja.\n\nLembre-se: quanto menor o numero, maior a prioridade' \
         0 0 -20 +20 0 || $backTo) 
      # Acima: Dialog para definir a prioridade com a qual o processo deverá ser iniciado.
   pExNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Perm. de Exec.' \
         --menu 'Quanto a permissao de execucao:' \
         0 0 0 \
         '1' 'O arquivo ja eh executavel' \
         '2' 'Torna-lo executavel com u+x' \
         '3' 'Torna-lo executavel com g+x' \
         '4' 'Torna-lo executavel com o+x' \
         '5' 'Torna-lo executavel com a+x' || $backTo)
      # Acima: Opção para escolher como tornar o arquivo executável.
   if [ $pExNewProc == '1' ] # Inicio da condição que define o que vai ser feito de acordo com a escolha do menu acima.
      then # Dependendo da escolha, as variaveis recebem determinado valor que será usado mais tarde.
         pExConfirm='O arquivo ja eh executavel'
         pExDo='-'
      elif [ $pExNewProc == '2' ]
         then
            pExConfirm='Torna-lo executavel com u+x'
            pExDo='u+x'
      elif [ $pExNewProc == '3' ]
         then
            pExConfirm='Torna-lo executavel com g+x'
            pExDo='g+x'
      elif [ $pExNewProc == '4' ]
         then
            pExConfirm='Torna-lo executavel com o+x'
            pExDo='o+x'
      elif [ $pExNewProc == '5' ]
         then
            pExConfirm='Torna-lo executavel com a+x'
            pExDo='a+x'
   fi # Fim da condição
   bgfgNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Bg/Fg' \
         --menu "\nDeseja iniciar o processo em primeiro ou segundo plano?\n" \
         0 0 0 \
         'Primeiro' 'Primeiro Plano' \
         'Segundo' 'Segundo Plano' || $backTo)
   case $bgfgNewProc in
      Primeiro) bgfgNewProc="Primeiro Plano" ; bgfgNewProcDo='' ;;
      Segundo) bgfgNewProc="Segundo Plano" ; bgfgNewProcDo='&' ;;
   esac
      # Acima: Escolha para iniciar o processo em primeiro ou segundo plano.
      # Caso a escolha seja "Segundo Plano", é adicionado o '&' à variável que complementará o comando futuramente. Caso contrário, ela fica vazia.
   confirmNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Confirmacao' \
         --yesno "\nEstas informacoes estao corretas?\n\nCaminho: $pathNewProc\nArgumentos: $argsNewProc\nPrioridade: $niceNewProc\nPermissao de execucao: $pExConfirm\nExecutar em $bgfgNewProc\n" \
         0 0 || (dialog \
            --sleep 1 \
            --backtitle 'Gerenciador de Processos' \
            --title '' \
            --infobox "\nOperacao abortada!\n" \
            0 0 ; $backTo))
      runNewProc
      # Acima: Confirmação das informações colhidas. Caso estejam corretas, vai para a função que executa o novo processo (runNewProc), caso contrário, exibe mensagem de erro e volta para a função padrão (Menu de Processos)
   $backTo # Volta para a função pré-determinada.
} # Fim da função

procFilhos(){ # Função: Exibir os processos filhos do(s) processo(s) selecionado(s).
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   ps --header --lines 15 -o $procInfoColumns --sort $procInfoSort --ppid $getProc > $tmpOutput || errorMsg # Armazena as informações sobre os processos filhos do escolhido na variável $tmpOutput.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Processos Filhos' \
      --textbox $tmpOutput \
      0 0 || $backTo # Caixa de texto do Dialog exibindo as informações que foram gravadas em $tmpOutput.
   $backTo # Volta para a função pré-determinada.
}

procThreads(){ # Função: Exibir as threads do(s) processo(s) selecionado(s).
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   ps --header --lines 15 m -o $procInfoColumns --sort $procInfoSort $getProc > $tmpOutput || errorMsg # Armazena as informações sobre as threads do processo escolhido na variável $tmpOutput.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Processos Filhos' \
      --textbox $tmpOutput \
      0 0 || $backTo # Caixa de texto do Dialog exibindo as informações que foram gravadas em $tmpOutput.
   $backTo # Volta para a função pré-determinada.
}

runNewProc(){ # Inicia processo recém criado em 'menuCreateProc'.
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   if [ $pExDo != '-' ] #Condição que executa o comando 'chmod' apenas quando necessário. Conforme escolha no menu da função anterior (menuCreateProc).
      then # Caso a escolha do menu tenha sido DIFERENTE de "O arquivo ja é executavel"...
         chmod $pExDo $pathNewProc || errorMsg # ...Executa o 'chmod' conforme opção escolhida.
   fi # Fim da condição
   nice -n $niceNewProc $pathNewProc $argsNewProc $bgfgNewProcDo || errorMsg # Então o comando 'nice' inicia o processo recém "criado" com as opções (incluindo, obviamente, a prioridade) escolhidas.
   $backTo # Volta para a função pré-determinada.
} # Fim da função

menuEditProc(){ # Escolher como alterar determinado processo
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   menuEditProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Editar Processo Especifico' \
         --menu '' \
         0 0 0 \
         'Prioridade' 'Alterar prioridade' \
         'Sinal' 'Enviar sinal(signal) para Sair/Abortar/Parar/Continuar/...' \
         'Primeiro-Plano' 'Trazer processo para o primeiro plano' \
         'Plano-de-Fundo' 'Enviar processo para o plano de fundo' \
         'Informacoes' 'Visualizar informacoes sobre o processo' \
         'Filhos' 'Exibir os processos filhos do processo selecionado' \
         'Threads' 'Exibir as threads do processo selecionado' \
         'Outro' 'Escolher outro processo' \
         'Voltar' 'Voltar ao menu de processos' || $backTo)
         # Acima: Menu do dialog onde o usuário escolhe o que deseja fazer com um ou mais processos específicos.
   case $menuEditProc in # Inicio da condição que complementa o menu acima definindo as ações que cada escolha vai desencadear.
      Prioridade) reniceProc ;; # Caso seja escolhida a opção "Prioridade", o usuário será encaminhado diretamente para a função 'reniceProc'.
      Sinal) sigProc ;; # Caso seja escolhida a opção "Sinal", o usuário será encaminhado diretamente para a função 'sigProc'.
      Primeiro-Plano) bg $getProc || errorMsg ;; # Caso seja escolhida a opção "Primeiro-Plano", o processo escolhido anteriormente na função 'getProc' será trazido para o 'Primeiro plano'.
      Plano-de-Fundo) fg $getProc || errorMsg ;; # Caso seja escolhida a opção "Segundo-Plano", o processo escolhido anteriormente na função 'getProc' será enviado para o 'Segundo plano'.
      Informacoes) procInfo ;; # Caso seja escolhida a opção "Informações", o usuário será encaminhado diretamente para a função 'procInfo'.
      Filhos) procFilhos ;; # Caso seja escolhida a opção "Filhos", o usuário será encaminhado diretamente para a função 'procFilhos'.
      Threads) procThreads ;; # Caso seja escolhida a opção "Threads", o usuário será encaminhado diretamente para a função 'procThreads'.
      Outro) getProc ;;  # Caso seja escolhida a opção "Outro", o usuário será encaminhado diretamente para a função 'getProc'.
      Voltar) procChooseMode ;;  # Caso seja escolhida a opção "Voltar", o usuário será encaminhado diretamente para o menu anterior (Menu de Processos/Função 'procChooseMode').
   esac # Fim da condição
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

procState(){ # Função: Escolher quais processos listar
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela.
   procStateGrep=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Escolher Estado' \
         --radiolist 'Deseja visualizar processos que estao em qual estado?' \
         0 0 0 \
         '-' 'Todos' on \
         'R' 'Em execucao (Running)' off \
         'T' 'Parado (Stopped)' off \
         'X' 'Morto (Dead)' off \
         'Z' 'Zumbi (Defunct)' off \
         'D' 'Sono nao interrompivel (Uninterruptible Sleep)' off \
         'S' 'Sono interrompivel (Interruptible Sleep)' off || $backTo)
         # Acima: Radiolist do dialog onde o usuário escolhe de qual estado listar os processos.
   if [ $procStateGrep == '-' ] # Inicio da condição em que...
      then # ...caso a escolha, no menu anterior, tenha sido IGUAL a '-'...
         procList # ...vai direto para a função 'procList'.
      else # Caso a escolha, no menu anterior, tenha sido DIFERENTE de '-'...
         ps -u $procGetUsr -o pid,ppid,nlwp,pri,ni,pcpu,pmem,rss,vsz,stat,cmd --sort pid | grep "\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+$procStateGrep" > $tmpOutput || errorMsg
         # Acima: executa o comando ps e filtra a nona coluna ('stat') em busca da opção escolhida pelo usuário (e.g. 'S') e armazena o resultado no arquivo temporário.
         echo -e "PID\tPPID\tNo.Threads\tPrioridade\tNice\tUso CPU\tUso Mem\tRAM\tMem.Total\tUsuario\tComandoCompleto" > $tempHeader || errorMsg
         # Acima: E o cabeçalho das colunas é armazenado em outro arquivo temporário para ser utilizado, mais tarde, na concatenação.
         cat $tmpHeader $tmpOutput || errorMsg # Então o cabeçalho das colunas é concatenado no arquivo populado pelo 'ps' para facilitar o discernimento das informações.
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --title "Processos com o estado $procStateGrep" \
            --textbox $tmpOutput \
            0 0 || $backTo
         # Em seguida, o dialog exibe as informações do arquivo final, onde as informações dos processos escolhidos estão, junto com o seu cabeçalho.
   fi # E termina a condição.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

procChooseMode(){ # Função: Menu de processos.
   backTo=index # Determina a função 'index' (Menu Principal) como padrão para voltar.
   clear # Limpa a tela
   procChooseMode=$(dialog \
      --backtitle 'Gerenciador de Processos' \
      --stdout \
      --title 'Menu de processos' \
      --menu 'O que deseja fazer agora?' \
      0 0 0 \
      'Listar' 'Listar processos' \
      'Usuario' ' |->Escolher usuario dono dos processos' \
      'Colunas' ' |->Alterar colunas visiveis' \
      'Sortear' ' \->Alterar ordem de visualizacao' \
      'Estado' 'Visualizar apenas processos que estao em determinado estado' \
      'Especifico' 'Gerenciar um processo especifico' \
      'Novo' 'Iniciar novo processo com determinadas opcoes' \
      'Voltar' 'Voltar ao menu principal' || $backTo)
   # Acima: Menu do dialog onde o usuário define o que deseja fazer.
   case $procChooseMode in # Inicio da condição que complementa o menu definindo a ação de cada escolha.
      Listar) procList ;; # Caso seja escolhida a opção "Listar", o usuário será encaminhado diretamente para a função 'procList'.
      Usuario) procGetUsr ;; # Caso seja escolhida a opção "Usuário", o usuário será encaminhado diretamente para a função 'procGetUsr'.
      Colunas) procGetColumns ;; # Caso seja escolhida a opção "Colunas", o usuário será encaminhado diretamente para a função 'procGetColumns'.
      Sortear) procSortColumns;; # Caso seja escolhida a opção "Sortear", o usuário será encaminhado diretamente para a função 'procSortColumns'.
      Estado) procState ;; # Caso seja escolhida a opção "Estado", o usuário será encaminhado diretamente para a função 'procState'.
      Especifico) getProc ;; # Caso seja escolhida a opção "Especifico", o usuário será encaminhado diretamente para a função 'getProc'.
      Novo) menuCreateProc ;; # Caso seja escolhida a opção "Novo", o usuário será encaminhado diretamente para a função 'menuCreateProc'.
      Voltar) index ;;  # Caso seja escolhida a opção "Voltar", o usuário será encaminhado diretamente para o menu principal (função 'index').
   esac # Fim da condição
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

procList(){ # Função: Listar Processos
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   ps -L -u $procGetUsr --header --lines 15 -o $procGetColumns --sort $procSortColumns > $tmpOutput || errorMsg
   # Acima: Comando 'ps' lista os processos conforme as escolhas do usuário quanto à "Usuário dono do processo", "Colunas a serem exibidas" e "Classificar utilizando qual coluna".
   # A saída do comando ps foi enviada para o arquivo temporário.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Lista de processos' \
      --textbox $tmpOutput \
      0 0 || $backTo
   # Acima: Dialog exibe, em uma caixa de texto, o arquivo temporário utilizado logo acima.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

procGetColumns(){ # Função: Escolher colunas da listagem
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela
   procGetColumns=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --visit-items \
         --title 'Escolher colunas' \
         --buildlist 'Quais informações sobre os processos deseja visualizar?' \
         0 0 0 \
         'user' 'Nome do usuario dono do processo' on \
         'pid' 'ID do processo' on \
         'nlwp' 'Numero de threads' on \
         'pri' 'Prioridade original' on \
         'ni' 'Prioridade ajustada' on \
         'pcpu' '% da capacidade de processamento em uso' on \
         'pmem' '% de memoria em uso' on \
         'rss' 'Memoria RAM alocada' on \
         'vsz' 'Memoria total alocada' on \
         'stat' 'Estado do processo' on \
         'cmd' 'Comando (completo) que iniciou o processo' on \
         'class' 'Classes de agendamento' off \
         'comm' 'Comando (apenas nome) que iniciou o processo' off \
         'drs' 'Memoria fisica destinada ao codigo nao executavel' off \
         'label' 'Etiqueta de seguranca do processo' off \
         'lxc' 'Nome do container lxc em que o processo esta rodando' off \
         'lwp' 'IDs das threads' off \
         'pgid' 'ID de grupo de processo' off \
         'ppid' 'ID do processo pai' off \
         'psr' 'Processador cujo processo esta vinculado' off \
         'rtprio' 'Prioridade em tempo real' off \
         'ruser' 'Nome real do usuario dono do processo' off \
         'sid' 'ID da sessao que iniciou o processo' off \
         'size' 'Tamanho aprox. de SWAP' off \
         'start' 'Data/Hora de execução' off \
         'tid' 'ID da thread' off \
         'time' 'Tempo em que o processo ficou em execucao' off \
         'tty' 'Terminal no controle' off \
         'wchan' 'Funcao do kernel onde o processo esta dormindo' off || $backTo)
      procGetColumns=$(echo $procGetColumns | tr " " "," || errorMsg)
   # Acima: Os valores escolhidos na lista do dialog são armazenados na variável 'procGetColumns' para serem utilizados na listagem dos processos.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

procSortColumns(){ # Função: Escolher coluna a ser utilizada na classificação da lista de processos.
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela.
   procSortColumns=$(dialog \
      --backtitle 'Gerenciador de Processos' \
      --stdout \
      --visit-items \
      --title 'Escolher classificacao' \
      --menu 'Como deseja classificar a lista?' \
      0 0 0 \
      'class' 'Classes de agendamento' \
      'cmd' 'Comando (completo) que iniciou o processo' \
      'comm' 'Comando (apenas nome) que iniciou o processo' \
      'drs' 'Memoria fisica destinada ao codigo nao executavel' \
      'label' 'Etiqueta de seguranca do processo' \
      'lxc' 'Nome do container lxc em que o processo esta rodando' \
      'lwp' 'IDs das threads' \
      'ni' 'Prioridade ajustada' \
      'nlwp' 'Numero de threads' \
      'pcpu' '% da capacidade de processamento em uso' \
      'pgid' 'ID de grupo de processo' \
      'pid' 'ID do processo' \
      'pmem' '% de memoria em uso' \
      'ppid' 'ID do processo pai' \
      'pri' 'Prioridade original' \
      'psr' 'Processador cujo processo esta vinculado' \
      'rss' 'Memoria RAM alocada' \
      'rtprio' 'Prioridade em tempo real' \
      'ruser' 'Nome real do usuario dono do processo' \
      'sid' 'ID da sessao que iniciou o processo' \
      'size' 'Tamanho aprox. de SWAP' \
      'start' 'Data/Hora de execução' \
      'stat' 'Estado do processo' \
      'tid' 'ID da thread' \
      'time' 'Tempo em que o processo ficou em execucao' \
      'tty' 'Terminal no controle' \
      'user' 'Nome do usuario dono do processo' \
      'vsz' 'Memoria total alocada' \
      'wchan' 'Funcao do kernel onde o processo esta dormindo' || $backTo)
   # Acima: Menu onde deve ser selecionada a coluna utilizada na classificação da lista de processos. Escolha é armazenada na variável a ser utilizada no comando.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

procGetUsr(){ #Função: Escolher usuário ao qual os processos a serem listados pertencem.
   backTo=procChooseMode # Determina a função 'procChooseMode' (Menu de Processos) como padrão para voltar.
   clear # Limpa a tela.
   procGetUsr=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Escolher usuario' \
         --menu 'Deseja visualizar os processos de qual usuario?' \
         0 0 0 \
         $(grep [5-9][0-9][0-9] /etc/passwd | cut -d: -f1,3 --output-delimiter=" > :" | cut -d: -f1 || errorMsg) || $backTo)
   # A fim de preencher automaticamente o menu do dialog com os usuários comuns disponíveis no S.O., o comando 'grep' filtra o arquivo 'passwd' pelos UIDs 500 à 999; em seguida, o 'cut' é utilizado para separar o nome de usuário e adicionar uma seta ('>') destinada a não deixar uma das colunas do menu com aspas simples vazias (i.e. " username '' "). 
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

confirmExit(){ # Função: Confirmação de saída do script.
   backTo=index # Determina a função 'index' (Menu Principal) como padrão para voltar.
   clear # Limpa a tela.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --yesno '\nTem certeza que deseja sair?\n' \
      0 0 || $backTo #Dialog pedindo ao usuário confirmação de saída.
      clear # Caso queira sair, limpa a tela...
      exit # ...e sai do script.
} # Fim da função.

runNmon(){ # Função: Executar Nmon.
   backTo=index # Determina a função 'index' (Menu Principal) como padrão para voltar.
   clear # Limpa a tela.
   while true # Define ao laço de repetição um loop "eterno" (Até o usuário escolher finalizá-lo (a seguir), ou interrompê-lo com o Kill ou Ctrl+C)
      do # Inícia laço de repetição que mantém o 'nmon' rodando.
         dialog \
            --stdout \
            --backtitle 'Gerenciador de Processos' \
            --ok-label 'Nmon' \
            --cancel-label 'Menu principal' \
            --title 'Finalizar NMON' \
            --pause '\nDeseja voltar ao menu principal?\n(Continuando Nmon em 1 segundos...)\n' \
            10 0 1 || $backTo
         # Acima: Caixa do dialog ativa por 1 segundos. Caso o usuário aceite finalizar, gera código de saída 0.
         if [ $? -ne 0 ] # Início da condição que compara código de saída gerado pelo último comando (dialog) com 0.
            then # Se o código de saída for diferente de zero...
               index # ...volta ao menu principal.
            else # Se o código de saída for igual a zero... 
            nmon || errorMsg # ...executa nmon.
         fi # Fim da condição.
      done # Fim do laço de repetição.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

index() { # Função: Menu Principal
   backTo=confirmExit # Determina a função 'confirmExit' como padrão para voltar.
   clear # Limpa a tela.
   indexMenu=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --title 'Menu' \
         --menu 'O que deseja fazer?' \
         --stdout \
         0 0 0 \
         Gerenciar 'Gerenciar processos' \
         Nmon 'Executar Nmon' \
         Sair 'Finaliza o script'|| $backTo)
   # Menu do dialog pedindo ao usuário que decida o que fazer.
   case $indexMenu in # Inicio da condição que complementa o menu definindo as consequencias da ação escolhida pelo usuário.
      Gerenciar) procChooseMode ;; # Caso seja escolhida a opção "Gerenciar", o usuário será encaminhado diretamente para o menu de gerenciamento de processos (função 'procChooseMode').
      Nmon) runNmon ;; # Caso seja escolhida a opção "runNmon", o usuário será encaminhado diretamente para a função que iniciará o Nmon ('runNmon').
      Sair) confirmExit ;; # Caso seja escolhida a opção "Sair", o usuário será encaminhado diretamente para a confirmação de saída (função 'confirmExit').
   esac # Fim da condição.
   $backTo # Volta para a função pré-determinada.
} # Fim da função.

# Início do script: Validando o acesso administrativo. (Primeira parte executada pelo script)
clear # Limpa a tela.
if [ $UID != 0 ] # Condição comparando o UID do usuário atual com o UID do root.
   then # Caso o UID do usuário executando o script seja DIFERENTE de zero (root)...
      dialog \
         --sleep 3 \
         --backtitle 'Gerenciador de Processos' \
         --title 'Abortando Script' \
         --infobox '\nO acesso administrativo nao pode ser validado.\n\nTente executar o script novamente utilizando\nprivilegios administrativos (e.g. sudo).\n\n' \
         0 0
      # Acima: ...é mostrado um aviso no dialog notificando o usuário de que o script deve ser rodado pelo root, e então...
      exit # ...o script é encerrado.
   else # Caso o UID do usuário executando o script seja IGUAL a zero (root)...
   index # ...o script continua no menu principal (função 'index').
fi #Fim da condição

#

###########################################################################################
#
#Fonte bibliografica
#
#http://web.mit.edu/gnu/doc/html/features_5.html
#http://invisible-island.net/dialog/manpage/dialog.pdf
#https://www.ibm.com/support/knowledgecenter/ssw_aix_61/com.ibm.aix.cmds4/renice.htm
#https://www.ibm.com/support/knowledgecenter/ssw_aix_61/com.ibm.aix.cmds4/ps.htm
#http://linux.die.net/man/1/ps
#http://linux.die.net/man/1/tr
#http://linux.die.net/man/1/paste
#http://linux.die.net/man/1/cat
#http://linux.die.net/man/1/dialog
#http://linux.die.net/man/7/signal
#http://linux.die.net/man/1/kill
#https://criticalblue.com/news/wp-content/uploads/2013/12/linux_scheduler_notes_final.pdf
#http://linuxcommand.org/
#https://en.wikipedia.org/wiki/Unix_signal
#http://linux.die.net/man/1/bash
#
###########################################################################################
