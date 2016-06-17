#!/bin/bash
#===============================================================================    
# FATEC São Caetano
# Sistemas Operacionais - N3
#===============================================================================
# William Hanemann da Silva - williamhanemann@gmail.com
# Lucas de Paula - lucasdepaulags@gmail.com
# Kaio Cesar Ramos - kaio_cesar_ramos@hotmail.com
#===============================================================================
# Link para o script:
# (https://github.com/invenktive/gerenciador-processos-BASH/blob/master/ScriptN3.sh)
#===============================================================================
#
#                       Script Gerenciador de Processos v0.2.1
#
# Este script foi criado para facilitar o gerenciamento dos processos do linux
# Entre suas funcionalidades, encontram-se:
#   -Possibilidade de iniciar o Nmon e mantê-lo rodando até o momento em que o usuário desejar sair
#   -Listar os processos podendo-se escolher:
#      -Visualizar os processos de usuários específicos
#      -Escolher quais informações devem ser mostradas na listagem e sua ordem de vizualização
#      -Escolher como será sorteada a visualização
#   -Listar apenas processos em determinado estado
#   -Gerenciar um ou mais processos específicos simultaneamente:
#      -Localizador de PIDs com função de selecionar automaticamente os PIDs encontrados
#      -Possibilidade de digitar os PIDs
#      -Escolher os PIDs a partir de uma lista
#      -Alterar prioridades dos processos
#      -Enviar sinais
#      -Trazê-los para Primeiro plano escolhendo a partir de uma lista de jobs
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

# Variaveis

tmpHeader="$(mktemp)" # Cria arquivo temporário e armazena o caminho na variável tmpHeader.
tmpOutput="$(mktemp)" # Idem, mas armazena na variável tmpOutput.
procGetColumns="user,pid:7,nlwp:7,pri:7,ni:7,pcpu:7,pmem:7,rss:9,vsz:9,stat:6,cmd" # Define estas colunas como padrão para a listagem de processos.
procSortColumns="pid" # Define esta coluna como padrão para classificar a listagem de processos.
procGetUsr="$USER" # Define este usuário (root) como padrão para a listagem de processos.
procStateGrep='-' # Define '-' como escolha padrão para o filtro de estados de processos.
procInfoColumns="stat:6=Estado,nlwp:7=No.Threads,lwp:7=ThreadID,pri:7=Prioridade,ni:7=Nice,pcpu:7,pmem:7,rss:9=RAM,vsz:9=Mem.Total,user=Usuario,cmd=ComandoCompleto" # Define estas colunas como padrão para informações do processo.
procInfoSort="lwp" # Define esta coluna como padrão para classificar as informações do processo.

procInfo() { # Função: Informacoes sobre determinado(s) processos
   clear # Limpa a tela
   ps --header --lines 15 -o $procInfoColumns --sort $procInfoSort $getProc > $tmpOutput # Armazena as informações sobre o processo escolhido na variável $tmpOutput.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Informacoes do Processo' \
      --textbox $tmpOutput \
      0 0
   # Acima: Caixa de texto do Dialog exibindo as informações que foram gravadas em $tmpOutput.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   menuEditProc # Vai para o menu de gerenciamento de processos específicos.
} # Fim da função.

sigProc() { # Função: Enviar sinal ao processo
   clear # Limpa a tela
   killSig=$( \
      dialog \
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
         'STOP' '"Pausar" o processo [-19]' )
   # Acima: Menu em dialog para usuário escolher qual sinal enviar para o processo.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   kill -s $killSig -a $getProc # Utiliza a escolha do usuário para enviar o sinal.
   if [ $? -eq 0 ] # Se o retorno do dialog for igual a 0 (Sem "Erros"), mostra mensagem de sucesso, caso contrário, de falha.
      then
         dialog \
            --sleep 1 \
            --backtitle 'Gerenciador de Processos' \
            --title 'Sucesso' \
            --infobox "\nComando executado com sucesso!\n" \
            0 0
      else
         dialog \
            --sleep 1 \
            --backtitle 'Gerenciador de Processos' \
            --title 'Falha' \
            --infobox "\nFalha na execucao do comando!\n" \
            0 0
   fi
   menuEditProc # Vai para o menu de gerenciamento de processos específicos.
} # Fim da função.

reniceProc() { # Função: Alterar prioridade (renice)
   clear # Limpa a tela
      renicePrio=$( \
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Alterar Prioridade' \
            --rangebox '\nUtilize as teclas +/-/setas para ajustar a barra conforme a prioridade que deseja.\n\nLembre-se: quanto menor o numero, maior a prioridade' \
            0 0 -20 +20 0 )
   # Acima: Caixa do dialog para usuário alterar a prioridade do processo. E comando renice, que utiliza a escolha para alterá-la.
      if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
         then
            confirmExit
      fi
   renice -n $renicePrio -p $getProc
   if [ $? -eq 0 ] # Se o retorno do dialog for igual a 0 (Sem "Erros"), mostra mensagem de sucesso, caso contrário, de falha.
      then
         dialog \
            --sleep 1 \
            --backtitle 'Gerenciador de Processos' \
            --title 'Sucesso' \
            --infobox "\nComando executado com sucesso!\n" \
            0 0
      else
         dialog \
            --sleep 1 \
            --backtitle 'Gerenciador de Processos' \
            --title 'Falha' \
            --infobox "\nFalha na execucao do comando!\n" \
            0 0
   fi
   menuEditProc # Vai para o menu de gerenciamento de processos específicos.
} # Fim da função.

getProc(){ # Função: Escolher processo específico.
   clear # Limpa a tela
   getProcChoice=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --nocancel \
         --title 'Escolher Processo' \
         --menu '\nDeseja inserir o PID do processo ou escolhe-lo em uma Lista? \n\nObs.: Para localizar o PID de um processo, selecione "Localizar"' \
         0 0 0 \
         Lista '' \
         PID '' \
         Localizar '' )
   # Acima: Menu para o usuário escolher como deseja selecionar o(s) processo(s).
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   case $getProcChoice in # Condição complementar ao menu acima que define o que fazer a cada escolha.
      Lista) getProc=$( \
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --output-separator ' ' \
            --title 'Escolher Processo' \
            --checklist 'Quais processos deseja gerenciar?' \
            0 0 0 \
            $( ps -u $procGetUsr --no-header -o user,pid,comm | tr -s " " | cut -d " " -f 2,3 | cat -E | cut -d"$" -f 1- --output-delimiter " off " ) ) \
            ; if [ $? -ne 0 ] \
               ; then if [ $? -eq 1 ] \
                  ; then procChooseMode \
                  ; else confirmExit \
               ; fi \
            ; fi \
            ; menuEditProc ;;
      # Acima: Caso a escolha seja "Lista", mostra um menu com uma lista dos processos disponíveis.
      # A lista é obtida a partir do corte, adições e substituições na saída do comando ps.
      # Vai para o menu onde os processos escolhidos poderão ser gerenciados.
      # Se o retorno do dialog for diferente de 0, mas não 1, o usuário irá para a confirmação de saída do script. Caso seja 1 (Cancelar), volta para o menu.
      PID) getProc=$( \
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Escolher Processo' \
            --inputbox 'Digite o PID. Para varios PIDs, separe-os utilizando espacos.\n\nAtencao para a digitacao correta!' \
            0 0 ) \
            ; if [ $? -ne 0 ] \
               ; then if [ $? -eq 1 ] \
                  ; then procChooseMode \
                  ; else confirmExit \
               ; fi \
            ; fi \
            ; menuEditProc ;;
      # Acima: Caso a escolha seja "PID", o usuário insere, através do dialog, o(s) PID(s) que desejar.
      # Vai para o menu onde os processos escolhidos poderão ser gerenciados.
      # Se o retorno do dialog for diferente de 0, mas não 1, o usuário irá para a confirmação de saída do script. Caso seja 1 (Cancelar), volta para o menu.
      Localizar) procName=$( \
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Localizador de PIDs' \
            --inputbox 'Digite o nome do processo' \
            0 0 ) \
            ; if [ $? -ne 0 ] \
               ; then if [ $? -eq 1 ] \
                  ; then procChooseMode \
                  ; else confirmExit \
               ; fi \
            ; fi \
         ; findPID=$( \
            dialog \
               --backtitle 'Gerenciador de Processos' \
               --stdout \
               --output-separator ' ' \
               --title 'Escolher Processo' \
               --checklist 'Processos encontrados:\nQuais deles deseja gerenciar?' \
               0 0 0 \
               $( ps -C $procName --no-header -u $procGetUsr -o user,pid,cmd | tr -s ' ' | grep "\S\+\s\+\S\+\s\+\S\+$procName" | grep -v grep | cut -d ' ' -f 2,3 | cat -E | cut -d"$" -f 1- --output-delimiter " off " ) ) \
            ; if [ $? -ne 0 ] \
               ; then if [ $? -eq 1 ] \
                  ; then procChooseMode \
                  ; else confirmExit \
               ; fi \
            ; fi \
         ; getProc=$findPID \
         ; menuEditProc ;;
      # Acima: Caso a escolha seja "Localizar", o usuário insere, através do dialog, o nome do processo que procura; a partir do comando ps, após filtragem, cortes, adições e substituições, é criada uma lista dos processos com este nome, de onde são extraidos os PIDs formatados adequadamente para uso futuro.
      # Se o retorno do dialog for diferente de 0, mas não 1, o usuário irá para a confirmação de saída do script. Caso seja 1 (Cancelar), volta para o menu.
   esac # Fim da condição.
} # Fim da função

menuCreateProc() { # Função: Escolher como iniciar um novo processo.
   clear # Limpa a tela.
   pathNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Caminho' \
         --fselect '/' \
         20 60 )
   # Acima: Opção do dialog para escolher o caminho do processo que deverá ser iniciado.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão OK):
      then
         if [ $? -eq 1 ] # Se o retorno do dialog for igual a 1 (Botão Cancelar), volta ao menu anterior.
            then
               procChooseMode
            else # Caso contrário, vai para confirmação de encerramento.
               confirmExit
         fi
   fi
   pathNewProcIsOk=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Caminho' \
         --yesno "Caminho para o processo:\n\n $pathNewProc \n\nEsta correto?" \
         0 0 )
   # Acima: Confirmação do caminho do processo
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão OK):
      then
         if [ $? -eq 1 ] # Se o retorno do dialog for igual a 1 (Botão Cancelar), volta ao menu anterior.
            then
               procChooseMode
            else # Caso contrário, vai para confirmação de encerramento.
               confirmExit
         fi
   fi
   argsNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Argumentos' \
         --inputbox 'Digite os argumentos para a inicializacao do processo (e.g. -eLf, --help). Deixe em branco para "nenhum".' \
         0 0 ) 
   # Acima: Dialog onde usuário poderá inserir, opcionalmente, argumentos para a inicializacao do processo.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão OK):
      then
         if [ $? -eq 1 ] # Se o retorno do dialog for igual a 1 (Botão Cancelar), volta ao menu anterior.
            then
               procChooseMode
            else # Caso contrário, vai para confirmação de encerramento.
               confirmExit
         fi
   fi
   niceNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar processo: Prioridade' \
         --rangebox '\nUtilize as teclas +/-/setas para ajustar a barra conforme a prioridade que deseja.\n\nLembre-se: quanto menor o numero, maior a prioridade' \
         0 0 -20 +20 0 )
   # Acima: Dialog para definir a prioridade com a qual o processo deverá ser iniciado.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão OK):
      then
         if [ $? -eq 1 ] # Se o retorno do dialog for igual a 1 (Botão Cancelar), volta ao menu anterior.
            then
               procChooseMode
            else # Caso contrário, vai para confirmação de encerramento.
               confirmExit
         fi
   fi
   pExNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --nocancel \
         --title 'Iniciar Processo: Perm. de Exec.' \
         --menu 'Quanto a permissao de execucao:' \
         0 0 0 \
         '1' 'O arquivo ja eh executavel' \
         '2' 'Torna-lo executavel com u+x' \
         '3' 'Torna-lo executavel com g+x' \
         '4' 'Torna-lo executavel com o+x' \
         '5' 'Torna-lo executavel com a+x' )
      # Acima: Opção para escolher como tornar o arquivo executável.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão OK):
      then
         confirmExit
   fi
   if [ $pExNewProc == '1' ] # Inicio das condições que definem o que vai ser feito de acordo com a escolha do menu acima.
      then # Dependendo da escolha, as variaveis recebem determinado valor que será usado mais tarde.
         pExConfirm='O arquivo ja eh executavel'
         pExDo='-'
   fi
   if [ $pExNewProc == '2' ]
      then
         pExConfirm='Torna-lo executavel com u+x'
         pExDo='u+x'
   fi
   if [ $pExNewProc == '3' ]
      then
         pExConfirm='Torna-lo executavel com g+x'
         pExDo='g+x'
   fi
   if [ $pExNewProc == '4' ]
      then
         pExConfirm='Torna-lo executavel com o+x'
         pExDo='o+x'
   fi
   if [ $pExNewProc == '5' ]
      then
         pExConfirm='Torna-lo executavel com a+x'
         pExDo='a+x'
   fi # Fim das condições
   bgfgNewProcM=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --nocancel \
         --title 'Iniciar Processo: Bg/Fg' \
         --menu "\nDeseja iniciar o processo em primeiro ou segundo plano?\n" \
         0 0 0 \
         'Primeiro' 'Primeiro Plano' \
         'Segundo' 'Segundo Plano' )
   # Acima: Opção para iniciar o processo em primeiro ou segundo plano.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão OK):
      then
         confirmExit
   fi
   case $bgfgNewProcM in # Início da condição que complementa o menu definindo quais ações realizar com dependência à escolha realizada.
      Primeiro) bgfgNewProc="Primeiro Plano" ; bgfgNewProcDo='' ;; # Para iniciar em primeiro plano, a variavel que finalizará o comando (logo abaixo) fica vazia.
      Segundo) bgfgNewProc="Segundo Plano" ; bgfgNewProcDo='2>&1 &' ;; # A variavel que finalizará o comando (logo abaixo) recebe o valor 2>&1, para encaminhar o descritor stderr para o stdout, e o '&' para iniciar o processo em segundo plano.
   esac
   confirmNewProc=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Iniciar Processo: Confirmacao' \
         --yesno "\nEstas informacoes estao corretas?\n\nCaminho: $pathNewProc\nArgumentos: $argsNewProc\nPrioridade: $niceNewProc\nPermissao de execucao: $pExConfirm\nExecutar em $bgfgNewProc\n" \
         0 0 )
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0 (Botão Sim/OK):
      then
         if [ $? -eq 1 ] # Se o retorno do dialog for igual a 1 (Botão Não/Cancelar), volta ao menu anterior.
            then
               dialog \
                  --sleep 1 \
                  --backtitle 'Gerenciador de Processos' \
                  --title '' \
                  --infobox "\nOperacao abortada!\n" \
                  0 0
               procChooseMode
         else
            confirmExit
         fi
   fi
   runNewProc
   # Acima: Confirmação das informações colhidas. Caso estejam corretas, vai para a função que executa o novo processo (função 'runNewProc'), caso contrário, exibe mensagem de erro e volta para a função padrão (Menu de Processos)
} # Fim da função

procFilhos(){ # Função: Exibir os processos filhos do(s) processo(s) selecionado(s).
   clear # Limpa a tela
   ps --header --lines 15 -o $procInfoColumns --sort $procInfoSort --ppid $getProc > $tmpOutput # Armazena as informações sobre os processos filhos do escolhido na variável $tmpOutput.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Processos Filhos' \
      --textbox $tmpOutput \
      0 0 # Caixa de texto do Dialog exibindo as informações que foram gravadas em $tmpOutput.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   menuEditProc # Vai para o menu de gerenciamento de processos específicos.
}

procThreads(){ # Função: Exibir as threads do(s) processo(s) selecionado(s).
   clear # Limpa a tela
   ps --header --lines 15 m -o $procInfoColumns --sort $procInfoSort $getProc > $tmpOutput # Armazena as informações sobre as threads do processo escolhido na variável $tmpOutput.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Processos Filhos' \
      --textbox $tmpOutput \
      0 0 # Caixa de texto do Dialog exibindo as informações que foram gravadas em $tmpOutput.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   menuEditProc # Vai para o menu de gerenciamento de processos específicos.
}

runNewProc(){ # Inicia processo recém criado em 'menuCreateProc'.
   clear # Limpa a tela
   if [ $pExDo != '-' ] #Condição que executa o comando 'chmod' apenas quando necessário. Conforme escolha no menu da função anterior (menuCreateProc).
      then # Caso a escolha do menu tenha sido DIFERENTE de "O arquivo ja é executavel"...
         chmod $pExDo $pathNewProc # ...Executa o 'chmod' conforme opção escolhida.
   fi # Fim da condição
   nice -n $niceNewProc $pathNewProc $argsNewProc $bgfgNewProcDo
   # Acima: Então o comando 'nice' inicia o processo recém "criado" com as opções (incluindo, obviamente, a prioridade) escolhidas.
   procChooseMode # Volta para a função menu de processos.
} # Fim da função

bringFg(){ # Trazer processo para primeiro plano
   clear # Limpa a tela
   if [[ $(jobs) ]] # "Existem jobs?"
      then # Caso existam jobs...
         jobList=$( \
            echo $( jobs | rev | cat -E | rev ) > $tmpOutput \
               ; echo "$" >> $tmpOutput \
               ; fgProcID=$( cat $tmpOutput ) \
               ; echo $fgProcID | rev | tr -d ' ' | cut -d"$" -f 1- --output-delimiter="' '' '" | cut -c 2- | rev | cut -c 6- )
         # Acima: É criada uma lista dos jobs ativos utilizando cortes, inversoes, adições e trocas de chars, entre outras formas, no comando jobs.
         getFgProc=$( \
            dialog \
               --backtitle 'Gerenciador de Processos' \
               --stdout \
               --title 'Qual processo deseja trazer para o primeiro plano?' \
               --menu '' \
               0 0 0 \
               $( echo $jobList ) )
         # Acima: Utilizando o resultado da variável 'jobList' (Acima), o menu lista as opções para que o usuário defina qual processo trazer para o primeiro plano.
         if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
            then
               confirmExit
         fi
         fgProcID=$( echo $getFgProc | cut -d']' -f 1 | cut -c 3- ) # A opção escolhida é recortada para manter apenas o 'jobID'.
         fg $fgProcID # O comando 'fg' utiliza o jobID para trazer o processo para primeiro plano.
         if [ $? -eq 0 ] # Se o retorno do dialog for igual a 0 (Sem "Erros"), mostra mensagem de sucesso, caso contrário, de falha.
            then
               dialog \
                  --sleep 1 \
                  --backtitle 'Gerenciador de Processos' \
                  --title 'Sucesso' \
                  --infobox "\nComando executado com sucesso!\n" \
                  0 0
            else
               dialog \
                  --sleep 1 \
                  --backtitle 'Gerenciador de Processos' \
                  --title 'Falha' \
                  --infobox "\nFalha na execucao do comando!\n" \
                  0 0
         fi
      else
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Aviso' \
            --msgbox 'Nao existem jobs a serem listados' \
            0 0
      fi
   menuEditProc # Vai para o menu de gerenciamento de processos específicos.
}

menuEditProc(){ # Escolher como alterar determinado processo
   clear # Limpa a tela
   menuEditProcVar=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --title 'Gerenciar Processo Especifico' \
         --menu 'Escolha uma opcao:' \
         0 0 0 \
         'Prioridade' 'Alterar prioridade' \
         'Sinal' 'Enviar sinal(signal) para Sair/Abortar/Parar/Continuar/...' \
         'Primeiro-Plano' 'Trazer processo para o primeiro plano' \
         'Plano-de-Fundo' 'Enviar processo para o plano de fundo' \
         'Informacoes' 'Visualizar informacoes sobre o processo' \
         'Filhos' 'Exibir os processos filhos do processo selecionado' \
         'Threads' 'Exibir as threads do processo selecionado' \
         'Outro' 'Escolher outro processo' \
         'Voltar' 'Voltar ao menu de processos' )
         # Acima: Menu do dialog onde o usuário escolhe o que deseja fazer com um ou mais processos específicos.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   case $menuEditProcVar in # Inicio da condição que complementa o menu acima definindo as ações que cada escolha vai desencadear.
      Prioridade) reniceProc ;; # Caso seja escolhida a opção "Prioridade", o usuário será encaminhado diretamente para a função 'reniceProc'.
      Sinal) sigProc ;; # Caso seja escolhida a opção "Sinal", o usuário será encaminhado diretamente para a função 'sigProc'.
      Primeiro-Plano) bringFg ;; # Caso seja escolhida a opção "Primeiro-Plano", o processo escolhido anteriormente na função 'getProc' será trazido para o 'Primeiro plano'.
      Plano-de-Fundo) kill -19 $getProc \
         ; ok1=$( echo $? ) \
         ; kill -18 $getProc \
         ; ok2=$( echo $? ) \
         ; if [ $ok1 -eq 0 ] && [ $ok2 -eq 0 ] \
            ; then dialog \
               --sleep 1 \
               --backtitle 'Gerenciador de Processos' \
               --title 'Sucesso' \
               --infobox "\nComando executado com sucesso!\n" \
               0 0 \
            ; else dialog \
               --sleep 1 \
               --backtitle 'Gerenciador de Processos' \
               --title 'Falha' \
               --infobox "\nFalha na execucao do comando!\n" \
               0 0 \
         ; fi \
         ;  menuEditProc ;; # Caso seja escolhida a opção "Segundo-Plano", o processo escolhido anteriormente na função 'getProc' será enviado para o 'Segundo plano'. Em caso de erro em algum dos comandos 'kill', a mensagem de falha é mostrada; caso contrário, a de sucesso.
      Informacoes) procInfo ;; # Caso seja escolhida a opção "Informações", o usuário será encaminhado diretamente para a função 'procInfo'.
      Filhos) procFilhos ;; # Caso seja escolhida a opção "Filhos", o usuário será encaminhado diretamente para a função 'procFilhos'.
      Threads) procThreads ;; # Caso seja escolhida a opção "Threads", o usuário será encaminhado diretamente para a função 'procThreads'.
      Outro) getProc ;;  # Caso seja escolhida a opção "Outro", o usuário será encaminhado diretamente para a função 'getProc'.
      Voltar) procChooseMode ;;  # Caso seja escolhida a opção "Voltar", o usuário será encaminhado diretamente para o menu anterior (Menu de Processos/Função 'procChooseMode').
   esac # Fim da condição.
} # Fim da função.

procState() { # Função: Escolher quais processos listar
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
         'S' 'Sono interrompivel (Interruptible Sleep)' off )
         # Acima: Radiolist do dialog onde o usuário escolhe de qual estado listar os processos.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   if [ $procStateGrep == '-' ] # Inicio da condição em que...
      then # ...caso a escolha, no menu anterior, tenha sido IGUAL a '-'...
         procList # ...vai direto para a função 'procList'.
      else # Caso a escolha, no menu anterior, tenha sido DIFERENTE de '-'...
         ps -u $procGetUsr -o pid,ppid,nlwp,pri,ni,pcpu,pmem,rss,vsz,stat,cmd --sort pid | grep "\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+\S\+\s\+$procStateGrep" > $tmpOutput
         # Acima: executa o comando ps e filtra a nona coluna ('stat') em busca da opção escolhida pelo usuário (e.g. 'S') e armazena o resultado no arquivo temporário.
         echo -e "PID\tPPID\tNo.Threads\tPrioridade\tNice\tUso CPU\tUso Mem\tRAM\tMem.Total\tUsuario\tComandoCompleto" > $tempHeader
         # Acima: E o cabeçalho das colunas é armazenado em outro arquivo temporário para ser utilizado, mais tarde, na concatenação.
         cat $tmpHeader $tmpOutput # Então o cabeçalho das colunas é concatenado no arquivo populado pelo 'ps' para facilitar o discernimento das informações.
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --title "Processos com o estado $procStateGrep" \
            --textbox $tmpOutput \
            0 0
         if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
            then
               confirmExit
         fi
         # Em seguida, o dialog exibe as informações do arquivo final, onde as informações dos processos escolhidos estão, junto com o seu cabeçalho.
   fi # E termina a condição.
   procChooseMode # Volta para a função menu de processos.
} # Fim da função.

procChooseMode() { # Função: Menu de processos.
   clear # Limpa a tela
   menuChooseMode=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --nocancel \
         --stdout \
         --title 'Menu de processos' \
         --menu 'O que deseja fazer agora?' \
         0 0 0 \
         'Listar' 'Listar processos' \
         'Colunas' ' |->Alterar colunas visiveis' \
         'Sortear' ' \->Alterar ordem de visualizacao' \
         'Estado' 'Visualizar apenas processos que estao em determinado estado' \
         'Especifico' 'Gerenciar um processo especifico' \
         'Novo' 'Iniciar novo processo com determinadas opcoes' \
         'Usuario' 'Escolher outro usuario' \
         'Voltar' 'Voltar ao menu principal' )
   # Acima: Menu do dialog onde o usuário define o que deseja fazer.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   case $menuChooseMode in # Inicio da condição que complementa o menu definindo a ação de cada escolha.
      Listar) procList ;; # Caso seja escolhida a opção "Listar", o usuário será encaminhado diretamente para a função 'procList'.
      Colunas) procGetColumns ;; # Caso seja escolhida a opção "Colunas", o usuário será encaminhado diretamente para a função 'procGetColumns'.
      Sortear) procSortColumns ;; # Caso seja escolhida a opção "Sortear", o usuário será encaminhado diretamente para a função 'procSortColumns'.
      Estado) procState ;; # Caso seja escolhida a opção "Estado", o usuário será encaminhado diretamente para a função 'procState'.
      Especifico) getProc ;; # Caso seja escolhida a opção "Especifico", o usuário será encaminhado diretamente para a função 'getProc'.
      Novo) menuCreateProc ;; # Caso seja escolhida a opção "Novo", o usuário será encaminhado diretamente para a função 'menuCreateProc'.
      Usuario) procGetUsr ;; # Caso seja escolhida a opção "Usuário", o usuário será encaminhado diretamente para a função 'procGetUsr'.
      Voltar) index ;;  # Caso seja escolhida a opção "Voltar", o usuário será encaminhado diretamente para o menu principal (função 'index').
   esac # Fim da condição
} # Fim da função.

procList() { # Função: Listar Processos
   clear # Limpa a tela
   ps -L -u $procGetUsr --header --lines 15 -o $procGetColumns --sort $procSortColumns > $tmpOutput
   # Acima: Comando 'ps' lista os processos conforme as escolhas do usuário quanto à "Usuário dono do processo", "Colunas a serem exibidas" e "Classificar utilizando qual coluna".
   # A saída do comando ps foi enviada para o arquivo temporário.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --title 'Lista de processos' \
      --textbox $tmpOutput \
      0 0
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   # Acima: Dialog exibe, em uma caixa de texto, o arquivo temporário utilizado logo acima.
   procChooseMode # Volta para a função menu de processos.
} # Fim da função.

procGetColumns() { # Função: Escolher colunas da listagem
   clear # Limpa a tela
   procGetColumns=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --nocancel \
         --visit-items \
         --title 'Escolher colunas' \
         --buildlist 'Quais informações sobre os processos deseja visualizar?' \
         0 0 0 \
         'user' 'Nome do usuario dono do processo' on \
         'pid:7' 'ID do processo' on \
         'nlwp:7' 'Numero de threads' on \
         'pri:7' 'Prioridade original' on \
         'ni:7' 'Prioridade ajustada' on \
         'pcpu:7' '% da capacidade de processamento em uso' on \
         'pmem:7' '% de memoria em uso' on \
         'rss:9' 'Memoria RAM alocada' on \
         'vsz:9' 'Memoria total alocada' on \
         'stat:6' 'Estado do processo' on \
         'cmd' 'Comando (completo) que iniciou o processo' on \
         'class:7' 'Classes de agendamento' off \
         'comm' 'Comando (apenas nome) que iniciou o processo' off \
         'drs:7' 'Memoria fisica destinada ao codigo nao executavel' off \
         'label:7' 'Etiqueta de seguranca do processo' off \
         'lxc:7' 'Nome do container lxc em que o processo esta rodando' off \
         'lwp:7' 'IDs das threads' off \
         'pgid:7' 'ID de grupo de processo' off \
         'ppid:7' 'ID do processo pai' off \
         'psr:7' 'Processador cujo processo esta vinculado' off \
         'rtprio:7' 'Prioridade em tempo real' off \
         'ruser' 'Nome de usuario real dono do processo' off \
         'sid:7' 'ID da sessao que iniciou o processo' off \
         'size:7' 'Tamanho aprox. de SWAP' off \
         'start:10' 'Data/Hora de execução' off \
         'tid:7' 'ID da thread' off \
         'time:10' 'Tempo em que o processo ficou em execucao' off \
         'tty:7' 'Terminal no controle' off \
         'wchan:7' 'Funcao do kernel onde o processo esta dormindo' off )
   # Acima: Os valores escolhidos na lista do dialog são armazenados na variável 'procGetColumns'.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   procGetColumns=$( echo $procGetColumns | tr " " "," ) # O conteúdo escolhido no menu é editado para futura utilização.
   procChooseMode # Volta para a função menu de processos.
} # Fim da função.

procSortColumns() { # Função: Escolher coluna a ser utilizada na classificação da lista de processos.
   clear # Limpa a tela.
   procSortColumns=$( \
      dialog \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --nocancel \
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
         'ruser' 'Nome de usuario real dono do processo' \
         'sid' 'ID da sessao que iniciou o processo' \
         'size' 'Tamanho aprox. de SWAP' \
         'start' 'Data/Hora de execução' \
         'stat' 'Estado do processo' \
         'tid' 'ID da thread' \
         'time' 'Tempo em que o processo ficou em execucao' \
         'tty' 'Terminal no controle' \
         'user' 'Nome do usuario dono do processo' \
         'vsz' 'Memoria total alocada' \
         'wchan' 'Funcao do kernel onde o processo esta dormindo' )
      # Acima: Menu onde deve ser selecionada a coluna utilizada na classificação da lista de processos. Escolha é armazenada na variável a ser utilizada no comando.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   procChooseMode # Volta para a função menu de processos.
} # Fim da função.

procGetUsr() { # Função: Escolher usuário ao qual os processos a serem listados pertencem.
   clear # Limpa a tela.
   procGetUsr=$( \
      dialog \
         --stdout \
         --nocancel \
         --backtitle 'Gerenciador de Processos' \
         --title 'Escolher usuario' \
         --menu 'Deseja visualizar os processos de qual usuario?' \
         0 0 0 \
         $( cut -d: -f1,2,3 /etc/passwd | grep -e [1][0-9][0-9][0-9] | cut -d: -f1,3 --output-delimiter=' ' | cut -d: -f1 ) )
         ## Para RedHat: grep -e [5-9][0-9][0-9]  --  Para Debian: grep -e [1][0-9][0-9][0-9] ##
         # O arquivo 'passwd' é recortado e filtrado por UIDs 500 à 999 (RedHat). Em seguida, adaptado, através de recortes, ao modelo para ser usado como opções do menu.
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   if [ $procGetUsr == 'root' ] # Início da condição em que:
      then # Caso o valor da variável ainda seja "root"...
         dialog \
            --backtitle 'Gerenciador de Processos' \
            --stdout \
            --title 'Erro' \
            --msgbox 'Impossivel continuar como root.' \
            0 0
         # Acima: ...é exibida uma mensagem de erro e o script volta para o menu principal.
         if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
            then
               confirmExit
         fi
      else # Caso contrário...
         procChooseMode # ...continua para o menu de processos.
   fi # Fim da condição.
   index # Volta para o menu principal.
} # Fim da função.

runNmon() { # Função: Executar Nmon.
   clear # Limpa a tela.
   env NMON=$nmonExport nmon # Executa o nmon com a variavel de ambiente 'NMON' contendo as opções do usuário; desta forma, o nmon mostrará diretamente as informações desejadas.
   if [ $? -ne 0 ] # Se o retorno do dialog for igual a 0 (Sem "Erros"), mostra mensagem de sucesso, caso contrário, de falha.
      then
         dialog \
            --sleep 1 \
            --backtitle 'Gerenciador de Processos' \
            --title 'Falha' \
            --infobox "\nFalha na execucao do comando!\n" \
            0 0
   fi
   index # Volta para o menu principal.
} # Fim da função.

menuNmon() { # Função: Menu de opções do Nmon
   clear # Limpa a tela.
   menuNmonExport=$( \
      dialog \
         --nocancel \
         --backtitle 'Gerenciador de Processos' \
         --stdout \
         --output-separator ' ' \
         --title 'Menu de informações do Nmon' \
         --checklist 'O que deseja monitorar?' \
         0 0 0 \
         'c' 'CPU' off \
         'm' 'Memoria' off \
         'd' 'Disco' off \
         'r' 'Recursos' off \
         'n' 'Rede' off \
         'k' 'Kernel' off \
         'j' 'Filesystem' off )
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   # Acima: Menu para usuário escolher como deseja interagir com o nmon.
   nmonExport=$( echo $menuNmonExport | cut -d' ' -f 1- --output-delimiter="" ) # A escolha do usuário é recortada para servir ao modelo a ser utilizado mais tarde.
   runNmon # Continua para a função onde o 'nmon' será executado.
} # Fim da função.

confirmExit() { # Função: Confirmação de saída do script.
   clear # Limpa a tela.
   dialog \
      --backtitle 'Gerenciador de Processos' \
      --yesno '\nTem certeza que deseja sair?\n' \
      0 0
   # Acima: Dialog pedindo ao usuário confirmação de saída.
   if [ $? -ne 0 ] # Se NÃO for escolhida a opção 'Sim' (Sair), o usuário irá retornar ao menu principal.
      then index
   fi
   clear # Caso queira sair, limpa a tela...
   exit # ...e sai do script.
} # Fim da função.

index() { # Função: Menu Principal
   clear # Limpa a tela.
   indexMenu=$( \
      dialog \
         --stdout \
         --nocancel \
         --backtitle 'Gerenciador de Processos' \
         --title 'Menu' \
         --menu 'O que deseja fazer?' \
         0 0 0 \
         Gerenciar 'Gerenciar processos' \
         Nmon 'Menu de execução do Nmon' \
         Sair 'Finaliza o script' )
   if [ $? -ne 0 ] # Se o retorno do dialog for diferente de 0, o usuário irá para a confirmação de saída do script.
      then
         confirmExit
   fi
   # Menu do dialog pedindo ao usuário que decida o que fazer.
   case $indexMenu in # Inicio da condição que complementa o menu definindo as consequencias da ação escolhida pelo usuário.
      Gerenciar) procGetUsr ;; # Caso seja escolhida a opção "Gerenciar", o usuário será encaminhado a escolha do usuário (função 'procGetUsr').
      Nmon) menuNmon ;; # Caso seja escolhida a opção "menuNmon", o usuário será encaminhado para o menu de execução do Nmon.
      Sair) confirmExit ;; # Caso seja escolhida a opção "Sair", o usuário será encaminhado diretamente para a confirmação de saída (função 'confirmExit').
   esac # Fim da condição.
} # Fim da função.

# Início do script: Validando o acesso administrativo. (Primeira parte executada pelo script)
clear # Limpa a tela.
if [ $UID != 0 ] # Condição comparando o UID do usuário atual com o UID do root.
   then # Caso o UID do usuário executando o script seja DIFERENTE de zero (root)...
      dialog \
         --sleep 2 \
         --colors \
         --backtitle 'Gerenciador de Processos' \
         --title 'Abortando Script' \
         --infobox '\n\Z1O acesso administrativo nao pode ser validado.\Zn\n\nTente executar o script novamente utilizando\nprivilegios administrativos (\Z1e.g. sudo\Zn).\n\n' \
         8 51
      # Acima: ...é mostrado um aviso no dialog notificando o usuário de que o script deve ser rodado pelo root.
      exit # E então o script é encerrado.
   else # Caso o UID do usuário executando o script seja IGUAL a zero (root)...
      index # ...o script continua no menu principal (função 'index').
fi # Fim da condição

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
