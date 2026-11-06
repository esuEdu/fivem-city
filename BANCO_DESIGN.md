# Design do Banco — v1.1

> Complementa o `PROMPT_ECONOMIA_FIVEM.md`. Todas as regras de ouro de lá valem aqui.
> **No jogo tudo fica em inglês e em dólares (`$20,000`).** Este documento usa português, e os valores são em dólares inteiros.
> Legenda: ✅ decidido · 💡 proposta minha (confirmar) · ❓ em aberto · 🔜 fase futura · `[DEFINIR]` número de negócio.

---

## 1. Formas de pagamento ✅

| Forma | O que é | Onde usa |
|---|---|---|
| **Dinheiro** | Item `money` no inventário (o `cash` do `qbx_core` é só espelho dele) | Dar em mãos, lojas, depósito no ATM/agência |
| **App do banco (Pix)** | App no celular | Transferência para outro jogador, pagar cobranças, bloquear cartão |
| **Cartão** | Item `bank_card` | Maquininha (débito ou crédito), ATM (saque/depósito) |

## 2. Identidade e acesso ✅

- **Só o dono (e membros aprovados de conta compartilhada) acessam uma conta.** Roubar cartão ou celular não dá acesso à conta.
- **Digital** registrada na 1ª visita à agência e usada para revelar saldo e emitir cartão. É visual: por trás, o servidor confere o `citizenid` de quem está usando. O client nunca manda "digital ok".
- **App do celular** abre a conta de **quem está usando**, não a do dono do aparelho. Celular roubado não serve para fazer Pix nem para aprovar compras da vítima.
- O que o ladrão consegue com **cartão + PIN**: sacar/depositar no ATM e pagar na maquininha, **dentro dos limites que o dono configurou**. Não vê saldo, extrato, nem faz Pix.

## 3. Tipos de conta

| Tipo | Status | Regras |
|---|---|---|
| **Pessoal (corrente)** | ✅ | 1 por personagem, **criada automaticamente junto com o personagem**, com **$18.000** (mais **$2.000 em espécie**), lançados no ledger como `starting`. Recebe salário/Pix e o app funciona desde o início. A **1ª visita à agência** registra a digital e emite o 1º cartão. **Não pode ser compartilhada.** |
| **Poupança** | ✅ | Rende `[DEFINIR: 0,1%]` a cada 24h (job agendado no servidor). |
| **Compartilhada** | ✅ | Cada jogador pode **criar OU participar de 1** no total (`[DEFINIR]` para aumentar depois). |
| **Society/job** (polícia, governo, hospital…) | ✅ | Ver 3.3. |
| **Empresa** | 🔜 | Quando existir o sistema de empresas. |

Número de conta no estilo `LS 5801 8396`, **aleatório** (não sequencial).

### 3.1 Poupança e metas ✅

- Rendimento fixo configurável a cada 24h. 🔜 Depois: investimentos com risco (sobe/desce).
- ✅ **Rende sobre a média do saldo nas últimas 24h**, não sobre o saldo na hora do cálculo. Ex.: ficou R$ 0 por 22h e R$ 100.000 nas últimas 2h → a média é ~R$ 8.333, e o rendimento é calculado sobre isso.
  - 💡 Média **ponderada pelo tempo**, calculada a partir do ledger (cada movimentação marca quanto tempo aquele saldo ficou parado). É exata e não depende de "fotos" de hora em hora que dá pra burlar.
  - Teto de rendimento por ciclo `[DEFINIR]`; rendimento sai de `BANK_RESERVE` e é arredondado a favor da casa (regra 21).
- **Metas** por conta: valor-alvo + data, barra de progresso atualizada a cada movimentação.

### 3.2 Conta compartilhada ✅

1. A pessoa pede acesso pelo **número da conta**.
2. O **dono aprova** (app ou agência).
3. Depois de aprovado, o membro entra normalmente e faz só o que as permissões dele deixam, trocando o contexto pelo seletor de contas (Pessoal / Poupança / Compartilhada).

Permissões por membro: **Ver**, **Depositar**, **Sacar**, **Transferir**, **Gerenciar cartões**, **Gerenciar membros**.
💡 Limite de saque por hora/dia por membro; log de tudo com nome e horário; remover membro bloqueia na hora os cartões dele naquela conta.

**Cartões dos membros ✅:** cada membro com permissão emite o **próprio cartão** daquela conta na agência; o **dono define o limite de cada um**. O extrato mostra qual cartão/membro gastou.

### 3.3 Contas de job ✅

- Cada organização (polícia, governo, hospital…) tem conta própria.
- **Acesso restrito:** só **dono/subdono** do job e, no máximo, pessoas que eles escolherem para **visualizar**. Membros comuns da organização **não** acessam.
- 💡 Limite de saque por hora, log de tudo com nome e horário.
- **Multas ✅: valor dividido** entre governo (conta sistema) e conta da polícia, com % configurável `[DEFINIR: ex. 70% governo / 30% polícia]`. 💡 Sugestão: a parte da polícia com teto mensal, para não virar incentivo a multar em excesso.

## 4. Cartões ✅

- **Item físico**, emitido **só na agência** (Fleeca etc.). ATM, app e registradora não emitem.
- **Taxa de emissão** na 1ª via e em toda 2ª via `[DEFINIR]`.
- Pode ter **vários cartões**, cada um vinculado a **uma conta**.
- **Débito e crédito no mesmo cartão**: na maquininha o cliente escolhe a função. Crédito usa o limite do tier e entra na fatura.
- **PIN de 4 dígitos**. Errou **3x → bloqueado**; desbloqueio **só na agência**.
- Tiers por score (A–E do prompt / Classic → Black): definem o teto dos limites, o limite de crédito e os benefícios.

### 4.1 Limites e aprovação no celular ✅

Dois níveis de limite:
- **Limite liberado (teto):** definido **pelo banco** (por enquanto staff configurada para isso; depois, banqueiros). Respeita o teto do tier. **Só o banco aumenta.**
- **Limite em uso:** o dono ajusta **dentro do teto**, subindo ou baixando, pelo app ou na agência. **Qualquer mudança (subir ou baixar) só vale depois de 1 minuto.** Para parar um roubo na hora, o caminho é **bloquear o cartão** pelo app (imediato).

Limites **por cartão**:

| Limite | Exemplo |
|---|---|
| Débito por dia | `[DEFINIR]` |
| Crédito por dia | `[DEFINIR]` |
| Saque no ATM por dia | `[DEFINIR]` |
| Aproximação por compra / por dia | `[DEFINIR]` (baixo) |

**Aproximação ✅:** vem **desligada** no cartão novo; o dono ativa no app ou na agência e define o limite.

**Compra acima do limite → pedido de aprovação no app do dono:**
- Notificação no celular: "Compra de R$ X em [loja/jogador], aprovar?".
- **Dono offline, sem celular, recusou ou não respondeu em 60 s → negado.**
- Só o dono aprova (o app abre pelo `citizenid`, então celular roubado não aprova).
- Regra de RP da cidade (não técnica): proibido sequestrar a vítima para forçar a aprovação.

### 4.2 Bloqueio por roubo ✅

- **Bloquear: só pelo app do celular** (botão "comunicar roubo/perda").
- **Desbloquear: só na agência.**
- Se o ladrão levou o celular também: a vítima vai direto à agência ou compra um celular novo para bloquear pelo app.
- 💡 "Comunicar roubo" invalida aquele `card_id` para sempre; na agência o dono emite 2ª via (com taxa).
- **2ª via sempre bloqueia o cartão anterior** daquela mesma conta/titular.

### 4.4 Morte e prisão ✅ (mecânicas de outros scripts; o banco só reage)

**Morte** (script de morte/inventário):
- O loot fica **no corpo** por ~`[DEFINIR: 500]` s; outros jogadores podem saquear (dinheiro/cartão/celular trocam de inventário normalmente).
- Depois disso o jogador aperta **E** e dá respawn no hospital; o que ainda estava com ele vai **para o limbo** (destruído).
- Volta ao normal comprando celular novo e tirando **2ª via** do cartão na agência (o antigo é bloqueado).

**Prisão** (script de polícia/prisão):
- Itens **ilegais** são removidos (inclui `black_money`); **todo o resto fica** com o jogador (celular, cartão, chaves, dinheiro limpo…).

**Contrato de integração 💡** (para a auditoria de conservação fechar):
- Saque do corpo = troca de inventário comum, sem lançamento especial.
- Dinheiro destruído no respawn → o script de morte chama `exports.economy:DestroyCash(src, 'death_loss')` em vez de remover o item direto (regra 16). Vai para `WORLD_SINK`.
- `black_money` confiscado na prisão → `exports.economy:DestroyCash(src, 'confiscated', 'dirty')` → vai para `GOV_TREASURY` ou sumidouro `[DEFINIR]`.
- Cartão destruído não mexe em saldo; só fica órfão até o dono pedir 2ª via (que o bloqueia).

### 4.3 Segurança do cartão (servidor) 💡

- Item guarda **só `card_id` aleatório** + dados visuais (nome impresso, final do número, design). Nunca PIN, saldo ou limite.
- PIN com **hash + salt** no banco (`SHA2(CONCAT(salt, pin), 256)`); comparação só no servidor.
- **Tentativas de PIN contadas por cartão**, no servidor (trocar de ATM ou de personagem não zera).
- Para usar, o servidor confere que o cartão **está no inventário de quem usa, naquele slot**.
- 2ª via = **novo `card_id`**; o antigo vira plástico inútil (anti-dupe).
- Item `bank_card` só é criado pelo resource do banco.

## 5. ATM ✅

1. Lista **os cartões no seu inventário** (não lista contas).
2. Escolhe o cartão e digita o PIN.
3. **Sacar** ou **depositar**.

**Saque e depósito sempre exigem cartão + PIN**, inclusive **na agência**. Quem perdeu o cartão tira a 2ª via na agência e depois saca. (Na agência, sem cartão, dá para ver a conta, tirar 2ª via, desbloquear cartão e gerenciar tudo pelo painel; só a movimentação de espécie exige o cartão.)

**Saldo com "olhinho":** o saldo aparece escondido. Clicou no olho → pede a **digital**:
- dono/membro da conta → mostra o saldo;
- outra pessoa → **"Fingerprint invalid"**.
- 🔒 O servidor **não envia o saldo** quando o ATM abre; só depois de conferir que quem clicou é dono/membro. Senão o ladrão leria o saldo no payload da NUI.

O ladrão consegue tentar sacar (até os limites), mas não descobre quanto a vítima tem.

**Saque alto:** acima de `[DEFINIR]` **não é feito no ATM**. Precisa ser **presencial na agência**. 🔜 Com banqueiros jogadores, passa a precisar do aval deles.

**Depósito alto:** acima de `[DEFINIR]` deposita normalmente, mas gera **log + flag** para a staff.

💡 **Log do ATM** (local, horário, cartão, quem usou) para a polícia investigar no RP.

## 6. Maquininha (POS) ✅

- **Item** comprado por jogador/empresa `[DEFINIR preço]`. O dinheiro cai na conta vinculada à maquininha.

**Fluxo:**
1. O lojista digita o valor e envia a cobrança para um jogador **próximo**.
2. O cliente recebe a requisição, escolhe o cartão no inventário e abre um menu com a **imagem da maquininha**, com o **valor no visor**.
3. O cliente escolhe débito ou crédito e paga de um dos dois jeitos:
   - **Inserir:** arrasta o cartão para a **parte de baixo** (encaixe do chip) e digita o **PIN**.
   - **Aproximação** (se ativada no cartão): passa o cartão na **parte de cima**, sem PIN.
4. Acima do limite → aprovação no celular do dono (4.1).
5. Aprovado → o lojista recebe na hora. Se o cliente não pagar a fatura do cartão depois, é problema entre ele e o banco, não com o vendedor.

💡 **Validações no servidor:**
- distância entre lojista e cliente, checada nos dois momentos (cobrança e pagamento);
- maquininha no inventário do lojista;
- valor ≤ teto da maquininha;
- a cobrança tem `id` e expira em `[DEFINIR]` s;
- 1 cobrança aberta por maquininha;
- o valor cobrado é o que o servidor guardou na cobrança, nunca o que o client do cliente reenviar.

🔒 **Exceção controlada:** é o único lugar onde um valor vem do client (o lojista digita). Por isso: validação de valor (regra 13), teto de $100.000, o pagador vê o valor no visor antes de pagar, e o item maquininha **só nasce de compra na loja** (nenhum outro resource cria esse item, mesma lógica da regra 16).

💡 Taxa da maquininha para o lojista (MDR) `[DEFINIR]`% → governo/sumidouro.
💡 Item **comprovante** opcional para os dois (valor, data, `tx_id`).

### 6.1 Lojas NPC ✅

- **Configurável por loja**: só dinheiro, só cartão, ou ambos (ex.: concessionária só cartão/transferência; barraquinha só dinheiro).
- Pagamento com cartão em loja NPC usa a mesma tela da maquininha (inserir + PIN ou aproximação); o "lojista" é o sistema e o preço vem do config do servidor.

## 7. Cobranças (aba "Cobranças") ✅

- A aba mostra **as cobranças feitas PARA o jogador**: multas, serviços, parcelas, fatura do cartão. O jogador **não** cobra outros por aqui, e **não existe "pedir dinheiro"**.
- Quem emite:
  - **Polícia → multas.** Em serviço, perto do alvo, valor da tabela de infrações.
  - **Estabelecimentos → cobrança de serviço.** Uso raro: o normal é passar o cartão. 💡 Só jobs/empresas autorizadas, perto do cliente, com teto por job.
- **Pagamento:** fica **pendente com prazo** `[DEFINIR]` dias.
- **Venceu:**
  - juros `[DEFINIR]`;
  - score cai;
  - **30% de tudo que entra na conta** (salário, Pix, depósito em espécie) vai automaticamente para quitar a dívida até zerar. Vale **só na conta pessoal do devedor** (não na compartilhada nem na de job).
- **Restrições por atraso ✅** (dias `[DEFINIR]`):

| Atraso | Restrição |
|---|---|
| Venceu | Sem crédito novo (empréstimo, subir de tier) |
| X dias | Função **crédito** do cartão bloqueada (débito continua) |
| Y dias | **Pix/transferências com limite reduzido** (não dá pra esvaziar a conta e fugir da dívida) |
| Z dias (longo) | **Conta congelada**: só recebe; precisa ir à agência negociar |

- **A conta nunca fica negativa.**
- 🔒 **Tipos de congelamento** (`freeze_reason`): `debt` (dívida — destrava ao negociar na agência), `fraud` (anti-cheat — só staff destrava) e `admin` (manual — só staff destrava). Os três deixam a conta **receber**, mas não enviar nem sacar.

## 8. Empréstimos ✅

- **Automático** até o máximo do score/tier (cada tier tem seu teto, juros e nº de parcelas).
- **Acima disso: manual**, aprovado por staff ou banqueiro.
- Simulação antes de confirmar: juros, valor da parcela, total a pagar.
- Parcela cobrada automaticamente; inadimplência segue as regras de cobrança (seção 7).
- 🔜 Garantia com imóvel quando houver sistema de casas.

## 9. Transferências agendadas ✅

- **Só de jogador para jogador** por enquanto.
- Valor, destino, frequência `[DEFINIR opções]`, referência; pausar/retomar/cancelar.
- 💡 Executadas pelo scheduler do servidor; sem saldo na hora → falha, notifica e não tenta de novo naquele ciclo.

## 10. Painel do banco (agência) e app

| Aba | Agência | App | Status |
|---|---|---|---|
| Dashboard (saldo, entradas/saídas 24h, score, dívidas) | ✅ | ✅ | ✅ |
| Contas (pessoal, poupança, compartilhada, metas, membros) | ✅ | ver | ✅ |
| Cartões: emitir / desbloquear | ✅ | ❌ | ✅ |
| Cartões: bloquear / limites / aproximação | ✅ | ✅ | ✅ |
| Transferências (Pix) e agendadas | ✅ | ✅ | ✅ |
| Empréstimos | ✅ | ver/pagar | ✅ |
| Cobranças (multas, serviços, faturas) | ✅ | ✅ | ✅ |
| Histórico | ✅ | ✅ | ✅ |
| Aprovar compra acima do limite | — | ✅ | ✅ |
| Fundos / Mercado / Empresas | — | — | 🔜 |

❌ **Cofre (vault): não terá na cidade.**

## 11. Agências

- ✅ Por enquanto do **governo/staff**.
- 🔜 Dono jogador: taxa de serviço, aprovar empréstimos e saques altos, capital de giro travado.
- O modelo de dados já nasce com `branch_id` e `owner`.

---

## 12. Integrações com o servidor (Qbox)

| Tema | Onde vive hoje | Como fica |
|---|---|---|
| Saldo `cash`/`bank` do `qbx_core` | `qbx_core` | Espelho somente leitura; escrita delegada para `city_economy` (patch). `crypto` removido. |
| Scripts de terceiros que pagam/cobram | ~25 resources | Bloqueados pela **allowlist** até serem reescritos (ex.: taxi para de pagar). |
| Renewed-Banking | `[standalone]` | Removido; `city_bank` substitui. Sem exports genéricos de compatibilidade. |
| Salário | `qbx_core/server/loops.lua` (a cada 10 min) | Fonte registrada `salary` na allowlist; imposto de renda (13.10) aplicado ali. |
| Celular | npwd | App do banco é um **app npwd** (Pix, bloquear cartão, aprovar compra, limites). |
| Morte | `qbx_medical` / `qbx_ambulancejob` | Patch: espécie destruída no respawn via `DestroyCash(src, 'death_loss')`. |
| Prisão | `xt-prison` | Patch: `black_money` confiscado via economia (`confiscated`). |
| Bans | `qbx_core` | Estender com tokens (`GetPlayerTokens`). |
| Espécie como item | `server.cfg` (`inventory:accounts "[]"`) + `city_inventory` | Primeiro o `city_inventory` atualiza a economia quando o item `money` se move (drop, troca, baú, loot); depois `inventory:accounts '["money"]'`. |

Regras e números fechados. Nada em aberto.

---

## 13. Números ✅ (v1 aprovada)

**Âncoras:** emprego legal comum paga **~$5,000/h** (≈ $40,000 num dia de 8h jogadas) · juros **moderados** · prazos em **dias reais** · fatura **semanal (7 dias)**.
Valores aprovados para o lançamento; vão para `server/config_server.lua` e podem ser recalibrados depois com as métricas de massa monetária.

### 13.1 Tiers do cartão (score 0–1000)

| | E · Classic | D · Silver | C · Gold | B · Platinum | A · Black |
|---|---|---|---|---|---|
| Score mínimo | 0 | 400 | 550 | 700 | 850 |
| Débito / dia (teto) | 25.000 | 50.000 | 100.000 | 250.000 | 500.000 |
| Limite de crédito | 10.000 | 25.000 | 60.000 | 150.000 | 300.000 |
| Saque ATM / dia | 10.000 | 20.000 | 35.000 | 50.000 | 75.000 |
| Aproximação por compra / dia | 500 / 2.000 | 1.000 / 4.000 | 2.000 / 8.000 | 3.000 / 12.000 | 5.000 / 20.000 |
| Tarifa por ciclo (7 dias) | 0 | 0 | 500 | 1.500 | 3.000 |
| Cashback no crédito | 0% | 0% | 0,5% | 1% | 1,5% |
| Empréstimo automático até | 25.000 | 60.000 | 150.000 | 300.000 | 600.000 |
| Juros do empréstimo (total) | 15% | 12% | 10% | 8% | 6% |
| Parcelas semanais (máx.) | 4 | 6 | 8 | 10 | 12 |

- Personagem novo começa com **score 350** (Classic).
- Cashback sai de `BANK_RESERVE`, arredondado a favor da casa.
- Empréstimo acima do automático → manual (staff/banqueiro). 1 empréstimo ativo por vez.

### 13.2 Score (como sobe e desce)

| Evento | Pontos |
|---|---|
| Fatura paga integral em dia | +10 |
| Parcela de empréstimo em dia | +5 |
| Empréstimo quitado | +25 |
| Cada 7 dias de conta ativa sem atraso | +5 |
| Pagou só o mínimo da fatura | −5 |
| Cobrança/fatura/parcela vencida | −30 (uma vez) e −5/dia de atraso |
| Conta congelada por atraso | −100 |

Ganho máximo de **+40 por semana** (ninguém sobe de Classic a Black em poucos dias). Perda não tem teto.

### 13.3 Fatura do cartão de crédito

| Item | Valor |
|---|---|
| Ciclo | 7 dias reais |
| Vencimento | 3 dias após o fechamento |
| Pagamento mínimo | 20% da fatura |
| Rotativo (sobre o que não foi pago) | 5% por ciclo |

### 13.4 Cobranças, multas e atraso

| Item | Valor |
|---|---|
| Prazo para pagar | 7 dias |
| Atraso | multa 2% + 0,5% ao dia, **máximo 20%** da dívida |
| Retenção automática do que entra | 30% |
| Venceu (dia 0) | sem crédito novo |
| 3 dias | função crédito bloqueada |
| 7 dias | Pix/transferência limitado a 10.000/dia |
| 15 dias | conta congelada (só recebe; negociar na agência) |
| Divisão das multas | 70% governo · 30% polícia |
| Teto da parte da polícia | 500.000 a cada 30 dias (o excedente vai para o governo) |

### 13.5 Pix e transferências

| Item | Valor |
|---|---|
| Taxa (pessoa física) | 0 |
| Por transação | 200.000 |
| Por dia | 500.000 |
| Noturno (22h–6h, horário real do servidor) | 30.000 no período |
| Conta nova (primeiras 10h jogadas) | 20.000/dia |
| Transferência agendada | mesmas regras + frequência diária, semanal ou a cada 14 dias |

### 13.6 ATM, agência e depósitos

| Item | Valor |
|---|---|
| Saque por operação no ATM | até 50.000 (acima: **só na agência**) |
| Depósito que gera log + flag | 50.000 numa operação ou 150.000 em 24h |
| Tentativas de PIN | 3 (bloqueio, desbloqueio só na agência) |

### 13.7 Cartão, maquininha e lojas

| Item | Valor |
|---|---|
| Emissão 1ª via | 500 |
| 2ª via | 1.500 |
| Maquininha (item) | 3.000 |
| Taxa da maquininha (MDR) | 2% débito · 3% crédito (vai para o governo) |
| Teto por cobrança na maquininha | 100.000 |
| Cobrança da maquininha expira em | 60 s |
| Aprovação no celular expira em | 60 s |

### 13.8 Contas

| Item | Valor |
|---|---|
| Poupança | 0,1% a cada 24h sobre a média do saldo; **máximo 1.000/dia** |
| Conta compartilhada: saque padrão por membro | 20.000/dia (o dono ajusta) |
| Conta de job: saque máximo | 50.000/hora |
| Mudança de limite do cartão | vale após 60 s |

### 13.9 Tetos globais e detecção (ligam com o prompt)

| Item | Valor |
|---|---|
| Maior operação única possível | 5.000.000 |
| Saldo máximo de uma conta | 1.000.000.000 (muito abaixo de 2^53) |
| Ganho máximo por hora num job legal | 10.000 (2× a média) → acima disso não paga + flag |
| Flag de "ganho rápido demais" | ganho líquido/h > 3× a média da cidade |
| Loot no corpo | 500 s |

### 13.10 Imposto de renda (retido na fonte, sobre salário/jobs)

| Ganho no dia (real) | Alíquota |
|---|---|
| Até 20.000 | 0% |
| 20.000 – 60.000 | 5% |
| Acima de 60.000 | 10% |
