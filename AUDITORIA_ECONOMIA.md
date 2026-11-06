# Auditoria — Economia e Banco × Projeto fivem-city

> Cruzamento de `PROMPT_ECONOMIA_FIVEM.md` + `BANCO_DESIGN.md` com o **código real do servidor** e com `CLAUDE.md` / `docs/standards/*`.
> Objetivo: saber o que precisa mudar **antes** de escrever o primeiro script.
> Legenda: 🔴 bloqueia o início · 🟠 resolver na fase 1 · 🟡 ajustar no documento · ✅ já bate.

---

## 0. Decisões tomadas (aplicadas nos dois documentos)

| Achado | Decisão |
|---|---|
| A — fonte da verdade | `qbx_core` **delega** para `city_economy`; `PlayerData.money` vira espelho somente leitura. Escolhida pela segurança: um único ponto de entrada, e quem só lê o saldo (HUD etc.) não precisa mudar. |
| B — 25 scripts pagando direto | **Allowlist de fontes**: o que não está registrado não paga nem cobra. Cada script volta quando for reescrito. |
| C — espécie como item | Item `money` vira verdade; primeiro o `city_inventory` avisa a economia quando o item se move, depois liga `inventory:accounts`. Dinheiro sujo = `black_money`. |
| D — Renewed-Banking | **Removido, sem exports genéricos de compatibilidade.** Um `addAccountMoney(conta, valor)` genérico, sem fonte nem motivo, contrariaria a allowlist. Os 4 dependentes ficam bloqueados até serem reescritos. |
| E — taxi e outros jobs | Param de pagar (allowlist) até serem reescritos no padrão da seção 11. |
| F — unidades | Dólares inteiros; moeda `$`. |
| Outros | `crypto` removido · personagem novo com $2.000 em espécie + $18.000 no banco · conta pessoal nasce com o personagem e o app funciona desde o início · saque/depósito sempre com cartão + PIN, inclusive na agência · jogo em inglês, documentos em português. |

## 1. Resumo

Os dois documentos batem entre si quase por completo. O problema maior é outro: **eles foram escritos para um servidor "standalone", e este servidor é Qbox.** Hoje o dinheiro vive no `qbx_core`, **25 resources** mexem nele direto, já existe um banco instalado (Renewed-Banking) e o dinheiro em espécie **não é item**.

| # | Achado | Gravidade |
|---|---|---|
| A | Projeto é Qbox, não standalone: o dinheiro mora no `qbx_core` | 🔴 |
| B | 25 resources chamam `AddMoney/RemoveMoney` direto, sem ledger | 🔴 |
| C | Dinheiro em espécie não é item hoje (`inventory:accounts "[]"`) | 🔴 |
| D | Renewed-Banking já instalado (banco, ATM, contas de job) | 🔴 |
| E | Jobs vendorizados aceitam valor vindo do client (ex.: taxi) | 🟠 |
| F | Centavos × reais inteiros do `qbx_core` | 🟠 |
| G | Nomes, pastas e convenções do projeto diferentes do prompt | 🟡 |
| H | Pequenas inconsistências entre os dois documentos | 🟡 |
| I | Mecânicas de outros scripts (morte, prisão, salário, celular) | 🟠 |

---

## 2. 🔴 A — O servidor é Qbox, não standalone

**O que o prompt diz:** "Sem framework. O resource de economia é a fonte única da verdade", identidade própria por `citizenid` gerado pelo resource, bridge para ox_inventory.

**O que existe:**
- `qbx_core` guarda `PlayerData.money` com os tipos `cash`, `bank` e `crypto` (`qbx_core/config/server.lua:8`), salva periodicamente e expõe `AddMoney/RemoveMoney/SetMoney` (`qbx_core/server/player.lua:1431`, `:1482`, `:1541`).
- O `citizenid` já é do Qbox; personagens e bans também.
- O inventário é o `city_inventory` (com exports iguais aos do ox_inventory), não o ox_inventory.

**Decisão necessária — de onde vem a verdade do dinheiro:**

| Opção | Como funciona | Prós | Contras |
|---|---|---|---|
| **1. `qbx_core` delega para a economia (recomendada)** | Patch no `qbx_core` (`scripts/patches/qbx_core.patch`, que já existe): `AddMoney/RemoveMoney/SetMoney` passam a chamar `city_economy`, que grava no ledger com débito atômico. `PlayerData.money` vira cache espelhado. | **Um único ponto de entrada**: os 25 scripts entram no ledger automaticamente, com tetos por `reason`, imposto e auditoria, sem patch em cada um. | Patch sensível no core; precisa de testes fortes. |
| 2. `qbx_core` continua dono, economia só registra | Ouve `QBCore:Server:OnMoneyChange` (`player.lua:1402`) e grava o ledger depois. | Simples, zero patch no core. | Não dá para **barrar** nada (o dinheiro já entrou); não há débito atômico; a auditoria vira só log. Quebra as regras 2, 4 e 5. |
| 3. Economia standalone ao lado do `qbx_core` | Saldos próprios e `qbx_core` ignorado. | Fiel ao prompt. | Dois saldos que não batem; os 25 scripts pagam "fora" do sistema. Inviável. |

➡️ **Ajuste nos documentos:** trocar a seção 2 do prompt ("Stack fixa") para Qbox + `city_inventory`, e registrar a opção escolhida como regra.

## 3. 🔴 B — 25 resources mexem no dinheiro direto

Arquivos com `AddMoney/RemoveMoney/SetMoney`: `qbx_vehicleshop` (4), `illenium-appearance` (4), `qbx_core` (4), `qbx_police` (2), `qbx_drugs` (2), `Renewed-Banking` (2), `city_inventory` (2) e mais 1 cada em `qbx_taxijob`, `qbx_truckerjob`, `qbx_towjob`, `qbx_garbagejob`, `qbx_busjob`, `qbx_diving`, `qbx_pawnshop`, `qbx_storerobbery`, `qbx_truckrobbery`, `qbx_streetraces`, `qbx_properties`, `qbx_garages`, `qbx_customs`, `qbx_cityhall`, `qbx_carwash`, `qbx_ambulancejob`, `qbx_adminmenu`, `qbx_vehiclesales`.

**Conflito com:** regras 1, 2, 4, 10, 11 e a seção 11 do prompt (todo pagamento por sessão controlada pelo servidor, com ledger).

**O que fazer:**
1. Com a opção 1, todos entram no ledger sem mudar nada neles. O `reason` que cada um passa vira a **fonte** do dinheiro (`job:taxi`, `shop`, `robbery:store`…).
2. **Rede de segurança imediata:** teto por hora por `reason`/fonte no `city_economy` (seção 13.9 do design: job legal > R$ 10.000/h → não paga + flag). Isso protege mesmo antes de revisar cada script.
3. Depois, revisar um a um com o fluxo `patch-script` (prioridade: os que **pagam**, principalmente jobs e roubos).
4. `qbx_adminmenu` (dar dinheiro) precisa passar pela regra 14 (motivo obrigatório + `admin_actions`).

## 4. 🔴 C — Dinheiro em espécie não é item hoje

**O design diz:** carteira = item `money`, roubável, com loot no corpo.

**O que existe:**
- `server.cfg:59` → `setr inventory:accounts "[]"`: o `cash` fica **só no `qbx_core`**, não no inventário.
- O item `money` existe em `city_inventory/data/items.lua:146`, mas não é usado.
- O `qbx_core` já tem o espelhamento pronto (`player.lua:12-17` e `:1410`): com `inventory:accounts '["money"]'`, cada mudança no `cash` faz `city_inventory:SetItem(source, 'money', valor)`.
- As trocas do `city_inventory` pagam em `cash` do `qbx_core` (`server/trades.lua:282`), não em item.

**O que fazer:**
1. Decidir **quem manda** no espécie: com o item virando verdade, toda movimentação do item `money` (drop, saque do corpo, troca, baú, porta-malas) precisa atualizar o `cash`, e vice-versa. Hoje só existe o sentido `qbx → item`.
2. Verificar no `city_inventory` o sentido `item → qbx` (mover/dropar/dar o item `money`) e escrever o que faltar. **Isso é pré-requisito** do ATM, da maquininha, do loot de morte e da auditoria de espécie.
3. Ligar `inventory:accounts '["money"]'` só depois do item 2 testado (senão o dinheiro duplica ou some).
4. **Dinheiro sujo:** o projeto já usa o item **`black_money`** (lojas ilegais em `data/shops.lua:132+`). Trocar `dirty_money` por `black_money` nos dois documentos.
5. O tipo `crypto` do `qbx_core` está fora do escopo: decidir se remove (está em `moneyTypes`).

## 5. 🔴 D — Renewed-Banking já instalado

`[standalone]/Renewed-Banking` traz banco, ATM, contas de job, membros e transações, com tabelas próprias. Ele é usado por `qbx_core/config/server.lua`, `qbx_ambulancejob`, `qbx_police` e `qbx_vehicleshop` (contas de job/society).

**Conflita com:** praticamente todo o `BANCO_DESIGN.md` (contas, ATM sem cartão, contas de job, UI).

**O que fazer:**
1. Substituir pelo `city_bank`.
2. **Antes de remover:** o `city_bank` precisa oferecer exports compatíveis com os que esses 4 resources usam (`GetJobAccount`, `addAccountMoney`, `removeAccountMoney`…), do mesmo jeito que o `ox_inventory` falso encaminha para o `city_inventory`. Assim nenhum script do Qbox quebra.
3. Migração: importar saldos de contas de job do Renewed para as contas de job novas (se já houver dados).

## 6. 🟠 E — Jobs vendorizados confiam no client

Exemplo real: `qbx_taxijob/server/main.lua:106` — `qb-taxi:server:NpcPay(payment)` **recebe o valor do client**, aceita até `maxFare = 2000` com cooldown de 5 s, e só confere se o jogador está perto do ponto de entrega.

➡️ Um executor parado no ponto de entrega chama esse evento a cada 5 s: **até R$ 1,44 milhão por hora.** É exatamente o ataque dos vídeos.

**O que fazer:** com a opção 1, o teto por fonte (`job:taxi` ≤ R$ 10.000/h) já corta isso. Depois, patch no taxi no padrão da seção 11 (o servidor calcula a corrida). Repetir a revisão nos outros jobs/roubos da lista do item B.
O taxi também faz `DropPlayer` direto, o que contraria `docs/standards/security.md` ("não kickar/banir automaticamente sem spec"); com a economia, vira flag.

## 7. 🟠 F — Centavos × reais inteiros

O prompt manda guardar **centavos** em `BIGINT`. O `qbx_core` arredonda o dinheiro para **reais inteiros** (`validateMoneyAmount`, `player.lua:1418`) e todos os scripts pagam em reais.

**Recomendação:** usar **reais inteiros** em tudo (ledger, contas, NUI). Frações de juros/taxas são resolvidas pela regra 21 (arredondar a favor da casa). Os valores da seção 13 já estão em reais. Ajustar a regra 3 do prompt.

## 8. 🟠 I — Mecânicas de outros scripts

| Tema | Onde vive | O que precisa |
|---|---|---|
| **Salário** | `qbx_core/server/loops.lua` (a cada `paycheckTimeout = 10` min) | Com a opção 1 entra no ledger como `salary`; o **imposto de renda** (13.10) é aplicado ali. |
| **Dinheiro inicial** | `moneyTypes = { cash = 500, bank = 5000 }` | Não está no design. Definir valores (e a conta pessoal nasce com esse saldo via ledger, `reason='starting'`). |
| **Morte** | `qbx_medical` / `qbx_ambulancejob` | Patch para chamar `DestroyCash(src, 'death_loss')` no respawn (seção 4.4 do design). |
| **Prisão** | `xt-prison` | Patch para confiscar `black_money` via economia (`'confiscated'`). |
| **Celular** | `npwd` (apps em `[npwd-apps]`) | O app do banco vira um **app npwd** (como `npwd_qbx_garages`): Pix, bloquear cartão, aprovar compra, limites. |
| **Bans** | `qbx_core` já tem bans | Estender com tokens (`GetPlayerTokens`) em vez de criar tabela nova do zero. |
| **Entidades** | `server.cfg` não define `sv_entityLockdown` | Ligar `strict` só depois de testar os jobs que spawnam veículo pelo client (risco de quebrar scripts do Qbox). |

## 9. 🟡 G — Convenções do projeto × prompt

| Prompt diz | Projeto exige | Ajuste |
|---|---|---|
| Resource `economy/` | `city_<feature>` | `city_economy` (ledger, contas, regras) + `city_bank` (agência, ATM, cartões, maquininha, NUI) |
| `exports.economy:Credit(...)` | Exports em PascalCase | `exports.city_economy:Credit(...)` ✅ (só o nome do resource) |
| Eventos livres | `<resource>:server:<ação>`; callbacks `<resource>:<ação>` | `city_bank:server:withdraw`, `city_bank:getCards` |
| `server/config_server.lua` | `server/config.lua` só em `server_scripts` | Renomear |
| Admin com `RegisterCommand` + `IsPlayerAceAllowed` | `lib.addCommand` com `restricted = 'group.admin'` + `exports.qbx_core:IsOptin` | Trocar a regra 14 |
| Logs/flags próprios | `lib.print.warn` (resource, source, motivo) | Fazer os dois: `lib.print.warn` + tabela de flags |
| Bridge para ox_inventory | `city_inventory` com exports estilo ox | Bridge aponta para `city_inventory` (ou usa o `ox_inventory` falso) |
| UI livre (imagens de referência laranja/verde) | `city_ui/theme.lua`, sem `backdrop-filter`, só `textContent` | Painel/ATM/maquininha usam o tema do projeto (acento amarelo) |
| Texto em PT | Texto do jogador **em inglês** + `locales/en.json` | ❓ Decidir: seguir o padrão (inglês) ou adicionar `locales/pt-br.json` |
| Arquivos sem limite | Máx. ~300 linhas por arquivo | Dividir por tema (`server/pix.lua`, `server/cards.lua`…) ✅ já previsto |
| Testes no `economy_pentest` | Testes unitários em `tests/<resource>/` com luajit (`scripts/check.sh`) | Funções puras (validação de valor, arredondamento, juros, score, média da poupança) ganham teste unitário; o `economy_pentest` fica para os testes in-game |
| `V.amount` com `tonumber` | Projeto valida com `type(x) == 'number'` antes | Rejeitar string em vez de converter (mais rígido) |
| Dropar/kickar | "Não kickar/banir automaticamente sem spec" | ✅ Já bate (padrão = flag/congelar) |

## 10. 🟡 H — Inconsistências entre os dois documentos

1. **Prompt ainda tem `[DEFINIR]`** que o design já definiu (ciclo de fatura, limites, juros). A regra de precedência resolve, mas o ideal é o prompt apontar para a seção 13 do design.
2. **`dirty_money` × `black_money`** (ver C).
3. **Congelamento:** o prompt congela por **fraude** (staff decide); o design congela por **dívida** (negocia na agência). São coisas diferentes → guardar `freeze_reason` (`fraud` / `debt` / `admin`) e só a dívida pode ser destravada na agência.
4. **Retenção de 30%:** dizer explicitamente que vale **só na conta pessoal do devedor** (não na compartilhada nem na de job) e também sobre **depósito em espécie**.
5. **Saque no ATM sem cartão:** o design diz que o ATM só funciona com cartão. Confirmar que **na agência** o dono saca/deposita sem cartão (pela digital).
6. **Saldo no ATM ("olhinho"):** registrar que o servidor **não manda o saldo** na abertura do ATM; ele só é enviado depois da checagem de dono/membro (senão o ladrão lê o saldo no payload da NUI).
7. **Maquininha:** é o único lugar onde um valor vem do client (o lojista digita). Registrar como exceção controlada: `V.amount`, teto de R$ 100.000, o pagador vê o valor no visor, e o item maquininha só nasce de compra na loja (mesma lógica da regra 16).
8. **Prompt seção 7** fala em ciclo de fatura e juros "por ciclo `[DEFINIR]`"; o design definiu rotativo de 5%/ciclo. Ok pela precedência.
9. **Ban/identidade:** o prompt manda gerar `citizenid` próprio; no Qbox ele já existe → usar o do Qbox.

---

## 11. O que fazer antes do primeiro script (checklist)

**Decisões (suas):**
- [ ] Opção de integração com o `qbx_core` (recomendada: **1**, `qbx_core` delega para `city_economy`).
- [ ] Reais inteiros em vez de centavos.
- [ ] Remover Renewed-Banking (com exports compatíveis no `city_bank`).
- [ ] Remover o tipo `crypto`.
- [ ] Idioma da UI (inglês do padrão ou pt-BR).
- [ ] Dinheiro inicial (espécie e banco).

**Ajustes nos documentos (eu faço depois das decisões):**
- [ ] Prompt seção 2 (stack) → Qbox + `city_inventory` + opção escolhida.
- [ ] Regra 3 → reais inteiros; regra 14 → `lib.addCommand` + `IsOptin`; seção 15 → `city_economy` / `city_bank` e `server/config.lua`.
- [ ] `dirty_money` → `black_money` nos dois.
- [ ] Itens 3–7 da seção 10 no design.
- [ ] Seção "Integrações" no design: salário, morte, prisão, npwd, bans, Renewed.

**Ordem técnica sugerida (substitui a seção 17 do prompt):**
1. `city_economy`: schema, ledger, `Credit/Debit/Transfer` atômicos, flags, eventos-isca, testes unitários.
2. Patch no `qbx_core` (opção 1) + teto por fonte → todos os 25 scripts passam pelo ledger.
3. Espécie como item: sentido `item → qbx` no `city_inventory` e depois `inventory:accounts '["money"]'`.
4. `city_bank` com exports compatíveis com o Renewed → remover o Renewed.
5. Agência, contas, cartões, ATM, maquininha; app npwd.
6. Cobranças, multas, empréstimos, poupança, scheduler.
7. Revisão dos jobs/roubos vendorizados (taxi primeiro).
