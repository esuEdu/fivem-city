# Pesca no Stardew Valley — referência de mecânicas

Levantamento de **tudo que acontece na pesca do Stardew Valley (versão 1.6)**, para servir de base ao nosso script de pesca (`city_fishing`). O objetivo é copiar as *regras e números*, não o jogo: nomes de itens, textos, arte e sons do Stardew não entram no servidor.

Fonte: Stardew Valley Wiki (páginas Fishing, Fish, Tackle, Bait, Crab Pot, Fish Pond, Roe, Fish Smoker, Trout Derby, SquidFest, Forge, Modding:Fish data, Modding:Location data), que documenta o código do jogo (`FishingRod`, `BobberBar`, `GameLocation`, `CrabPot`, `FishPond`). Onde algo **não veio da wiki** e foi reconstruído de memória do código, está marcado com ⚠️ e deve ser confirmado no código descompilado (`Stardew Valley.dll`) antes de fixar os números.

---

## 1. Fluxo de uma pescada

1. **Lançar**: o jogador segura o botão, uma barra de força enche, e ao soltar a linha vai a uma fração da distância máxima. Dá para desviar a boia 1 tile para os lados enquanto ela voa. Custa energia (seção 10).
2. **Espera**: a boia fica na água por um tempo aleatório (seção 3) até um peixe morder.
3. **Fisgada**: a boia treme, aparece um "!" e toca um som. O jogador tem que apertar o botão nesse momento (o encantamento Auto-Hook faz isso sozinho). Se perder a janela, a espera recomeça.
4. **Escolha do que veio**: o jogo decide *na fisgada* qual peixe ou item é (seção 4). Itens que não são peixe (lixo, algas, águas-vivas) vêm direto, **sem minigame**, e dão 3 XP.
5. **Minigame** (seção 5): manter o peixe dentro da barra verde até a barra de progresso encher. O baú de tesouro pode aparecer durante o minigame.
6. **Resultado**: tamanho, qualidade, XP, "Perfeito!", "Primeira captura!", "Novo recorde!", baú.

O relógio do jogo **para** durante o minigame em single-player (mas não no multiplayer). Para o FiveM isso não se aplica: o tempo nunca para.

---

## 2. Varas

| Vara | Preço | Requisito | Isca | Tackle | Observação |
|---|---|---|---|---|---|
| Vara de treino | 25 | — | não | não | Só pega peixes com dificuldade < 50. A barra verde usa nível 5 de pesca se o jogador estiver abaixo disso. O peixe sai sempre com o tamanho mínimo e a qualidade normal. |
| Vara de bambu | 500 | — | não | não | Vara inicial. |
| Fibra de vidro | 1.800 | Pesca 2 | sim | não | |
| Irídio | 7.500 | Pesca 6 | sim | 1 | |
| Irídio avançada | 25.000 | Maestria em pesca | sim | 2 | Dois tackles iguais podem somar o efeito (seção 7). |

As varas melhores **não** aumentam a barra verde. Elas só liberam espaços para isca e tackle.

**Encantamentos de vara** (da Forja):
- **Auto-Hook**: fisga sozinho quando o peixe morde.
- **Efficient**: lançar não gasta energia.
- **Master**: +1 nível de pesca enquanto a vara está na mão.
- **Preserving**: em cada mordida, 50% de chance de não gastar a isca nem o tackle (sorteado separadamente para cada tackle).

---

## 3. Tempo até morder

- O tempo base é um valor aleatório entre **0,6 s e 30 s**.
- Cada nível de pesca tira **0,25 s** do máximo.
- O Spinner tira **3,75 s** do máximo e o Dressed Spinner tira **7,5 s** (somam se forem dois).
- **Primeira mordida do lançamento** (o jogador ainda não perdeu nenhuma fisgada nesse lançamento): o mínimo e o máximo caem **25%**.
- **Isca** (mínimo e máximo):
  - Isca comum, ímã, isca mágica e isca direcionada: **−50%**
  - Isca selvagem e isca de desafio: **−62,5%**
  - Isca deluxe: **−67%**
- **Bolhas** na água: o peixe morde **4× mais rápido**. Num frenesi (seção 9), a espera cai pela metade.
- O mínimo nunca fica abaixo de **0,5 s**.

---

## 4. Qual peixe morde (tabela de spawn)

### 4.1 Dados de cada peixe (`Data/Fish`)

| Campo | Exemplo | Uso |
|---|---|---|
| dificuldade ("chance de dardo") | 80 | Vai de 15 (carpa) a 110 (Legend). Controla a agressividade do peixe no minigame e entra no XP. |
| comportamento | `floater` | `mixed`, `smooth`, `sinker`, `floater` ou `dart` |
| tamanho mín./máx. (polegadas) | 1 / 36 | |
| faixas de horário | `1200 1600` | O início é inclusivo e o fim exclusivo. Pode haver várias faixas. |
| clima | `sunny` | `sunny`, `rainy` ou `both` |
| profundidade máx. (`maxDepth`) | 4 | Distância mínima da margem, em tiles, para não sofrer penalidade. |
| chance base | 0.3 | |
| multiplicador de profundidade | 0.5 | |
| nível mínimo de pesca | 0 | |
| pode ser o peixe do tutorial | true | |

As estações e os lugares onde cada peixe aparece vêm da tabela da **localização**, não da tabela do peixe.

### 4.2 Lista de peixes por localização (`Data/Locations` → `Fish`)

Cada localização tem uma lista de entradas, somada à lista `Default` (que vale para todo lugar e contém o lixo). Campos de cada entrada:

- `Chance` (padrão 1), `Season`, `Condition`
- `FishAreaId`: sub-áreas do mapa (rio e lago no mesmo mapa). Também definem o que os covos pegam.
- `BobberPosition` / `PlayerPosition`: retângulos onde a boia tem que cair ou onde o jogador tem que estar. É assim que os lendários ficam presos a um ponto.
- `MinFishingLevel`
- `MinDistanceFromShore` / `MaxDistanceFromShore`
- `ApplyDailyLuck`: soma a sorte do dia à chance.
- `CuriosityLureBuff`: quanto o Curiosity Lure soma.
- `SpecificBaitBuff` (soma) e `SpecificBaitMultiplier` (padrão **1,66**): efeito da isca direcionada.
- `CatchLimit`: máximo de capturas por jogador, para sempre. Os lendários usam 1.
- `CanUseTrainingRod`: o padrão é permitir só dificuldade < 50.
- `IsBossFish`: mostra a coroa no minigame e dá 5× XP.
- `RequireMagicBait`
- `Precedence`: ordem em que as entradas são testadas (menor primeiro). As de mesmo valor são embaralhadas. Faixas usadas:
  - −1100 a −1000: itens globais prioritários
  - −200 a −100: lendários e segredos do local
  - −50 a −1: peixes prioritários
  - 0: peixes normais
  - 1 a 100: peixes de baixa prioridade
  - 1000+: lixo (último recurso)

### 4.3 Algoritmo de escolha

1. Junta a lista da localização com a lista `Default` e ordena por `Precedence`, embaralhando os empates.
2. Percorre a lista e **pega a primeira entrada que passa** em todos os testes: estação, condição, área, posição, nível, distância da margem, limite de capturas, isca mágica e, para peixes, horário e clima.
3. Para peixes, ainda há um sorteio de chance (`CheckGenericFishRequirements`):
   - `chance = chanceBase`
   - Se a distância da margem for menor que `maxDepth`, perde `multProfundidade × chance` para cada tile que falta.
   - ⚠️ Soma o bônus do nível de pesca (de memória: `+ nível/50`, ou seja +2% por nível). A vara de treino dá um bônus pequeno.
   - **A chance é limitada a 0,9.**
   - Depois do limite: Curiosity Lure (aumenta mais a chance de peixes raros), isca direcionada (`× 1,66`) e sorte do dia, se a entrada usar.
   - Sorteia; se falhar, passa para a próxima entrada.
4. Se nada passar, sai **lixo**.
5. **Bolhas**: para essa escolha, a distância da margem conta como **+1**. Isso não muda tamanho, qualidade nem baú.
6. **Isca mágica**: ignora estação, horário e clima. Continua valendo o tipo de água.
7. **Tutorial**: na primeira fisgada da vida do jogador vem sempre um peixe comum. Se o sorteio der outra coisa, vem um Sunfish. Nessa captura a barra de progresso **não desce**.

### 4.4 Distância da margem ("profundidade")

- Conta tiles de água entre a boia e a "terra" mais próxima: chão, ilhas, píeres e pontes de pedra contam como terra; pontes de madeira não. O valor máximo é **5**.
- Quanto mais longe da margem: menos lixo, peixes maiores e de melhor qualidade, mais chance de peixes difíceis e lendários, e baús melhores.
- O alcance máximo do lançamento depende do nível: no nível 0 são 3 tiles para cima ou para baixo e 4 para os lados, com +1 tile nos níveis 1, 4, 8 e 15. A força do lançamento é uma fração disso. Um lançamento "Max" (> 99%) não dá bônus nenhum; o que importa é onde a boia cai.

**Ideia para o FiveM**: a distância da margem pode ser a distância da boia até a costa (raycast ou `GetWaterHeight` em volta) ou, mais simples, faixas de zona: píer, beira e mar aberto.

---

## 5. O minigame (`BobberBar`)

### 5.1 Geometria
- Área total do minigame: **568 px** de altura.
- Barra verde: **96 px + 8 px por nível de pesca**, ou seja 176 px no nível 10.
  - Cork Bobber: +24 px cada. Isca deluxe: +12 px.
  - O nível passa de 10 com comida, encantamento Master e tempero Qi. O máximo prático é 284 px, metade da área.
- O "peixe" é um ícone que se move dentro da área.

### 5.2 Controles e física da barra
- Segurar o botão faz a barra **subir com aceleração**. Soltar faz ela **cair com gravidade**. Ela tem inércia: demora para inverter e passa do ponto com facilidade. Toques curtos seguram a barra no lugar.
- No fundo, a barra **quica** (o Lead Bobber tira o quique; dois tiram ainda mais).
- O Barbed Hook faz a barra "grudar" no peixe, puxando sozinha para o centro dele quando ela está em cima do peixe.

⚠️ Constantes de memória do `BobberBar.Update`, por tick de ~60 fps (confirmar no código):
```
gravidade = botao ? -0.25 : +0.25
velBarra += gravidade
posBarra += velBarra
se posBarra no fundo: velBarra = -velBarra * 2/3   (Lead Bobber: sem quique)
se posBarra no topo: velBarra = 0
```

### 5.3 Barra de progresso (captura)
- ⚠️ Começa em **30%**. Com o peixe dentro da barra verde sobe ~**0,2% por tick**. Fora dela desce ~**0,3% por tick** (de memória).
- Trap Bobber: desce **33% mais devagar**; dois Trap Bobbers, **50%**.
- Chega a 100%: pegou o peixe. Chega a 0: o peixe foge e o baú some junto.
- **Isca de desafio**: o peixe foge se sair da barra **3 vezes**, mas uma captura perfeita rende **3 peixes**, e cada escapada diminui essa quantidade.
- **Tamanho encolhe**: o peixe perde 1" a cada 0,8 s em que não está sendo puxado (fora da barra), até o tamanho mínimo.

### 5.4 Movimento do peixe (comportamentos)
| Tipo | Movimento |
|---|---|
| mixed | Padrão básico |
| smooth | Movimento mais estável, sem saltos bruscos |
| sinker | Acelera mais rápido para baixo |
| floater | Acelera mais rápido para cima |
| dart | Errático, com saltos até **2 × dificuldade %** maiores para cima e para baixo |

⚠️ Pseudocódigo do movimento (de memória, a estrutura é confiável e as constantes devem ser conferidas):
```
a cada tick:
  se rand < dificuldade * (smooth ? 20 : 1) / 4000:   -- escolhe novo alvo
      pct = min(99, dificuldade + rand(10,45)) / 100
      alvo = pos + rand(-espacoAcima, espacoAbaixo) * pct
  floater: acelExtra = max(acelExtra - 0.01, -1.5)
  sinker:  acelExtra = min(acelExtra + 0.01,  1.5)
  se |pos - alvo| > 3:
      acel = (alvo - pos) / (rand(10,30) + (100 - min(100, dificuldade)))
      vel += (acel - vel) / 5
  senão se não smooth e rand < dificuldade / 2000:
      alvo = pos ± rand(50,100)                     -- pulo curto
  dart e rand < dificuldade / 1000:
      alvo = pos ± rand(50, 100 + dificuldade*2)    -- pulo grande
  pos = clamp(pos + vel + acelExtra, 0, alturaArea)
```
Ou seja: quanto maior a dificuldade, mais vezes o peixe muda de alvo, mais longe vai e mais rápido acelera.

### 5.5 Captura perfeita
- É "Perfeito!" se o peixe **nunca saiu da barra verde**. Com Treasure Hunter, sair da barra só enquanto se pega o baú também conta.
- Efeitos: **+1 de qualidade** (só se o peixe já for prata ou ouro) e **XP × 2,4**.

### 5.6 Sonar Bobber e lendários
- Normalmente o minigame não mostra que peixe é.
- Lendários aparecem com uma **coroa**.
- O Sonar Bobber mostra o peixe já na fisgada.

---

## 6. Tamanho e qualidade

```
fator = (distMargem / 5) * ((nivelPar + 2) / 10) * (rand(90..110) / 100)
        -- nivelPar = nível arredondado para baixo até um número par.
        -- Abaixo do nível 10, nivelPar é sorteado entre o nível do jogador e 10.
fator = clamp(fator, 0, 1)

tamanho = floor(min + (max - min) * fator + 1)  polegadas
        -- encolhe 1" a cada 0,8 s fora da barra, até o mínimo
        -- captura imperfeita que termina exatamente no máximo: -1"
        -- por isso o maior tamanho possível é max+1, só com captura perfeita

qualidade base: fator < 0.33 normal | < 0.66 prata | >= 0.66 ouro
+1 por Quality Bobber (até 2)
depois: perfeita sobe +1 se a qualidade já for >= prata
máximo: irídio
```

| Base | +1 QB | +2 QB | Perfeita | Perf.+1 QB | Perf.+2 QB |
|---|---|---|---|---|---|
| Normal | Prata | Ouro | Normal | Ouro | Irídio |
| Prata | Ouro | Irídio | Ouro | Irídio | Irídio |
| Ouro | Irídio | Irídio | Irídio | Irídio | Irídio |

**Preço por qualidade**: normal ×1, prata ×1,25, ouro ×1,5, irídio ×2. As profissões Fisher (+25%) e Angler (+50%) multiplicam por cima.

Exemplo da tabela da wiki: à distância 1 da margem e nível 0-9, o peixe sai 100% normal. À distância 5 e nível 6+, sai 100% ouro.

---

## 7. Isca e tackle

### 7.1 Iscas (gastam 1 por lançamento)
| Isca | Espera | Efeito extra | Como obter |
|---|---|---|---|
| Isca | −50% | Menos lixo | Pesca 2; 1 bug meat; loja: 5 |
| Ímã | −50% | Chance de baú +15% | Pesca 9; 1 barra de ferro; loja: 1.000 |
| Isca selvagem | −62,5% | Chance de **2 peixes** de uma vez (não vale para lendário) | Evento de amizade; 10 fibra + 5 slime + 5 bug meat |
| Isca mágica | −50% | Ignora estação, horário e clima | Rara; minério radioativo + 3 bug meat |
| Isca deluxe | −67% | Barra verde +12 px | Pesca 4; 5 iscas + 2 musgo; loja: 100 |
| Isca de desafio | −62,5% | Perfeita = **3 peixes**; cada escapada tira um; 3 escapadas = perde o peixe | Maestria; 5 fragmentos de osso + 2 musgo |
| Isca direcionada (por peixe) | −50% | Chance desse peixe `× 1,66`; só se ele puder aparecer ali | Feita na Bait Maker a partir do peixe; vale 0,2 × preço do peixe |

### 7.2 Tackles (só nas varas de irídio; duram 20 mordidas; não gastam com lixo)
| Tackle | Efeito | Dois iguais |
|---|---|---|
| Spinner | −3,75 s no máximo de espera | −7,5 s |
| Dressed Spinner | −7,5 s | −15 s |
| Trap Bobber | Progresso desce 33% mais devagar fora da barra | 50% |
| Cork Bobber | Barra +24 px | +48 px |
| Lead Bobber | Barra não quica no fundo | Ainda menos quique |
| Treasure Hunter | Peixe não foge enquanto você pega o baú; baú +5% | +10% |
| Barbed Hook | Barra gruda no peixe (bom para peixe lento) | Gruda mais |
| Curiosity Lure | Aumenta a chance de peixes raros | Sem ganho extra |
| Quality Bobber | +1 qualidade | +2 qualidade |
| Sonar Bobber | Mostra o peixe na fisgada | Sem ganho extra |

---

## 8. Baú de tesouro

- Aparece entre **1 e 3 s** depois do início do minigame, como um ícone dentro da área.
- **Chance**: base **15%**
  - +15% com ímã
  - +5% por Treasure Hunter
  - +15% com a profissão Pirate
  - ± metade da sorte do dia (−5% a +5%)
  - +0,5% por ponto de buff de sorte
- Tem uma **barra de progresso própria**, que enche enquanto a barra verde fica sobre o baú. Se o peixe fugir, o baú some junto.
- XP × **2,2** se pegar o baú.
- Os **itens** do baú dependem da distância da margem, do nível de pesca e da sorte:
  - Mais perto da margem: pedra, madeira, carvão e cobre.
  - Distância 3: ferro, gemas de gelo e geodo congelado.
  - Distância 5: ouro, irídio, geodo de magma e gemas de fogo.
  - Em geral: iscas e tackles, livros perdidos, artefatos, anéis, botas e raros (um item lendário com ~0,6%, fragmento prismático com ~0,012%).
  - Os itens especiais usam `modSorte = (1 + sorteDia) * distMargem/5`, então a distância vale **5×** mais que a sorte.
  - Pode vir mais de um item, e o mesmo item em pilhas separadas.
- **Baú dourado** (depois da maestria): 25% ± sorte (no máximo 37,5%). Vem com ~27% mais itens, e cada item tem 50% de chance de ser trocado por um item "premium" (barra de irídio, livro de XP, comida de buff, tackles e iscas raras, pérola...). Cerca de 70% dos baús dourados trazem pelo menos um premium.
- Eventos podem colocar itens fixos: na Trout Derby, a etiqueta dourada vai no baú se houver um.

---

## 9. Bolhas e frenesi

- **Bolhas**: no máximo um ponto por área ao mesmo tempo. Nele o peixe morde 4× mais rápido e a distância conta +1 na escolha do peixe.
- **Frenesi** (1.6.4): 1% de chance de um ponto de bolhas virar frenesi. Só acontece antes das 23h, em 4 áreas, depois de (4 dias e 3 peixes) ou de 15 dias de jogo.
  - Anuncia "Frenesi de X em Y".
  - Ali só sai aquele peixe, e a espera cai pela metade.
  - Dura no mínimo 90 min de jogo. Depois disso, a cada 10 min há 10% de chance de acabar, e essa chance sobe +0,56% a cada verificação.
  - Lendários nunca viram frenesi.

---

## 10. Energia, XP e nível

- **Energia por lançamento**: 8 − 0,1 × nível, ou seja 8 no nível 0 e 7 no nível 10.
- **XP de um peixe**:
  ```
  xp = (qualidade + 1) * 3 + dificuldade / 3    -- qualidade: 0 normal, 1 prata, 2 ouro, 4 irídio
  se pegou o baú: xp = floor(xp * 2.2)
  se perfeita:    xp = floor(xp * 2.4)
  se lendário:    xp = floor(xp * 5)
  ```
  Usa a qualidade **de antes** do bônus da captura perfeita.
- Item que não é peixe: **3 XP**. Coletar o covo: **5 XP**, mesmo que venha lixo.
- XP acumulado por nível: 100, 380, 770, 1.300, 2.150, 3.300, 4.800, 6.900, 10.000, 15.000 (níveis 1 a 10).
- **O que cada nível libera** (receitas e loja):
  - 1: +1 tile de alcance
  - 2: isca, vara de fibra de vidro
  - 3: covo
  - 4: isca deluxe, +1 tile
  - 5: escolha de profissão
  - 6: vara de irídio, Spinner, Trap Bobber, Lead Bobber, Sonar
  - 7: Cork Bobber, Treasure Hunter
  - 8: Barbed Hook, Dressed Spinner, +1 tile
  - 9: ímã
  - 10: escolha de profissão
- **Profissões**:
  - Nível 5: **Fisher** (peixe +25%) ou **Trapper** (covo mais barato de fazer).
  - Nível 10, se escolheu Fisher: **Angler** (peixe +50%) ou **Pirate** (chance de baú dobrada, +15%).
  - Nível 10, se escolheu Trapper: **Mariner** (covo não pega lixo e todas as criaturas ficam igualmente prováveis) ou **Luremaster** (covo não precisa de isca).
- **Comida**: buffs temporários de nível de pesca, de +1 a +4, por alguns minutos. Somam com os buffs de outro tipo de comida.

---

## 11. Covos (crab pots)

- São colocados na água, com isca. **No dia seguinte** têm 1 item. É preciso pôr isca de novo todo dia (com Luremaster não precisa).
- **Algoritmo** (`CrabPot.DayUpdate`):
  1. Sem Mariner: **20%** de lixo direto (`CrabPotJunkChance`; 45% no lago da fazenda de praia).
  2. Depois testa cada criatura do tipo de água (`ocean` ou `freshwater`) **em sequência**, cada uma com a sua chance. A primeira que passar é o resultado.
  3. Se nenhuma passar, sai lixo.
  4. Na prática dá **~38% de lixo** com isca comum, ou ~30% com isca deluxe, selvagem ou direcionada.
- Com **Mariner**: nunca sai lixo, e todas as criaturas daquele tipo de água têm a mesma chance (mar 1/7, água doce 1/3).
- **Isca direcionada no covo**: a chance da criatura alvo vira ×4 se a base for < 0,1, ×3 se for < 0,2 e ×2 nos outros casos.
- **Isca deluxe**: a criatura sai com qualidade prata. **Isca selvagem**: 25% de chance de vir em dobro.
- **Mar**: lagosta, mexilhão, caranguejo, berbigão, camarão, ostra e amêijoa. **Água doce**: lagostim, caracol e periwinkle.
- **Lixo**: lixo comum, madeira flutuante, jornal molhado, CD quebrado e óculos quebrados (todos com a mesma chance; podem ser reciclados).

---

## 12. O que mais pode vir na vara

- **Lixo** e lixo reciclável.
- **Algas** e **alga marinha**.
- **Águas-vivas** (do mar, do rio e da caverna): são raras e servem de ingrediente para o defumador.
- Contam como "peixe" na coleção, mas **não** como peixe para receitas, loja, defumador ou viveiro.
- **Presentes** em pontos secretos do mapa: móveis e chapéus pescados em locais específicos (fonte da praça, lago do spa...). Para o FiveM, isso vira "itens secretos" pescados em coordenadas escondidas.
- Pérola (rara, no submarino do Night Market).

---

## 13. Peixes lendários

- São 5. Cada um fica num **ponto exato** do mapa, numa estação, às vezes com clima e com nível mínimo de pesca. Têm dificuldade de 80 a 110.
- **Só dá para pegar 1 de cada por jogador** (`CatchLimit = 1`).
- XP × 5 e coroa no minigame.
- O livro "Segredos dos peixes lendários" ensina onde eles ficam.

| Peixe | Preço | Onde/quando | Nível | Dif. |
|---|---|---|---|---|
| Crimsonfish | 1.500 | Ponta leste do píer, verão | 5 | 95 mixed |
| Angler | 900 | Perto da cachoeira norte, outono | 3 | 85 smooth |
| Legend | 5.000 | Lago da montanha perto do tronco, primavera com chuva | 10 | 110 mixed |
| Glacierfish | 1.000 | Ponta sul de uma ilhota no rio, inverno | 6 | 100 mixed |
| Mutant Carp | 1.000 | Esgoto, qualquer estação | 0 | 80 dart |

**Quest "Família estendida"** (lendários II): enquanto a quest está ativa, no lugar de cada lendário sai o "filho" dele. Não tem limite de capturas, não tem exigência de estação ou clima, e não dá o bônus de XP de lendário.

---

## 14. Lista completa de peixes de vara

Preço normal (prata/ouro/irídio = ×1,25/×1,5/×2). Dificuldade + comportamento. Tamanho em polegadas. XP base = XP de um peixe normal.

| Peixe | Preço | Local | Horário | Estação | Clima | Tam. | Dif. | XP |
|---|---|---|---|---|---|---|---|---|
| Pufferfish | 200 | Mar | 12–16h | Verão | Sol | 1–37 | 80 floater | 29 |
| Anchovy | 30 | Mar | Qualquer | Prim, Out | Qualquer | 1–17 | 30 dart | 13 |
| Tuna | 100 | Mar | 6–19h | Ver, Inv | Qualquer | 12–61 | 70 smooth | 26 |
| Sardine | 40 | Mar | 6–19h | Prim, Out, Inv | Qualquer | 1–13 | 30 dart | 13 |
| Bream | 45 | Rio | 18–2h | Todas | Qualquer | 12–31 | 35 smooth | 14 |
| Largemouth Bass | 100 | Lago montanha | 6–19h | Todas | Qualquer | 11–31 | 50 mixed | 19 |
| Smallmouth Bass | 50 | Rio, lago floresta | Qualquer | Prim, Out | Qualquer | 12–25 | 28 mixed | 12 |
| Rainbow Trout | 65 | Rio, lago montanha | 6–19h | Verão | Sol | 10–26 | 45 mixed | 18 |
| Salmon | 75 | Rio | 6–19h | Outono | Qualquer | 24–66 | 50 mixed | 19 |
| Walleye | 105 | Rio, lagos | 12–2h | Outono | Chuva | 10–41 | 45 smooth | 18 |
| Perch | 55 | Rio, lagos | Qualquer | Inverno | Qualquer | 10–25 | 35 dart | 14 |
| Carp | 30 | Lago montanha, bosque, esgoto | Qualquer | Todas | Qualquer | 15–51 | 15 mixed | 8 |
| Catfish | 200 | Rio, bosque, pântano | 6–24h | Prim, Out | Chuva | 12–73 | 75 mixed | 28 |
| Pike | 100 | Rio, lago floresta | Qualquer | Ver, Inv | Qualquer | 15–61 | 60 dart | 23 |
| Sunfish | 30 | Rio | 6–19h | Prim, Ver | Sol | 5–16 | 30 mixed | 13 |
| Red Mullet | 75 | Mar | 6–19h | Ver, Inv | Qualquer | 8–23 | 55 smooth | 21 |
| Herring | 30 | Mar | Qualquer | Prim, Inv | Qualquer | 8–21 | 25 dart | 11 |
| Eel | 85 | Mar | 16–2h | Prim, Out | Chuva | 12–81 | 70 smooth | 26 |
| Octopus | 150 | Mar | 6–13h | Verão | Qualquer | 12–49 | 95 sinker | 34 |
| Red Snapper | 50 | Mar | 6–19h | Ver, Out | Chuva | 8–26 | 40 mixed | 16 |
| Squid | 80 | Mar | 18–2h | Inverno | Qualquer | 12–49 | 75 sinker | 28 |
| Sea Cucumber | 75 | Mar | 6–19h | Out, Inv | Qualquer | 3–21 | 40 sinker | 16 |
| Super Cucumber | 250 | Mar | 18–2h | Ver, Out | Qualquer | 12–37 | 80 sinker | 29 |
| Ghostfish | 45 | Minas 20/60 | Qualquer | Todas | Qualquer | 10–36 | 50 mixed | 19 |
| Stonefish | 300 | Minas 20 | Qualquer | Todas | Qualquer | 14–16 | 65 sinker | 24 |
| Ice Pip | 500 | Minas 60 | Qualquer | Todas | Qualquer | 7–9 | 85 dart | 31 |
| Lava Eel | 700 | Minas 100, vulcão | Qualquer | Todas | Qualquer | 31–33 | 90 mixed | 33 |
| Sandfish | 75 | Deserto | 6–20h | Todas | Qualquer | 8–25 | 65 mixed | 24 |
| Scorpion Carp | 150 | Deserto (nível 4) | 6–20h | Todas | Qualquer | 12–33 | 90 dart | 33 |
| Flounder | 100 | Mar | 6–20h | Prim, Ver | Qualquer | 4–17 | 50 sinker | 19 |
| Midnight Carp | 150 | Lagos, rios da ilha | 22–2h | Out, Inv | Qualquer | 12–53 | 55 mixed | 21 |
| Sturgeon | 200 | Lago montanha | 6–19h | Ver, Inv | Qualquer | 12–61 | 78 mixed | 29 |
| Tiger Trout | 150 | Rio | 6–19h | Out, Inv | Qualquer | 10–21 | 60 dart | 23 |
| Bullhead | 75 | Lago montanha | Qualquer | Todas | Qualquer | 12–31 | 46 smooth | 18 |
| Tilapia | 75 | Mar, rios da ilha | 6–14h | Ver, Out | Qualquer | 11–31 | 50 mixed | 19 |
| Chub | 50 | Rio floresta, lago montanha | Qualquer | Todas | Qualquer | 12–25 | 35 dart | 14 |
| Dorado | 100 | Rio floresta | 6–19h | Verão | Qualquer | 24–33 | 78 mixed | 29 |
| Albacore | 75 | Mar | 6–11h e 18–2h | Out, Inv | Qualquer | 20–41 | 60 mixed | 23 |
| Shad | 60 | Rio | 9–2h | Prim, Ver, Out | Chuva | 20–49 | 45 smooth | 18 |
| Lingcod | 120 | Rio, lago montanha | Qualquer | Inverno | Qualquer | 30–51 | 85 mixed | 31 |
| Halibut | 80 | Mar | 6–11h e 19–2h | Prim, Ver, Inv | Qualquer | 10–34 | 50 sinker | 19 |
| Woodskip | 75 | Bosque secreto | Qualquer | Todas | Qualquer | 11–31 | 50 mixed | 19 |
| Void Salmon | 150 | Pântano | Qualquer | Todas | Qualquer | 24–66 | 80 mixed | 29 |
| Slimejack | 100 | Covil mutante | Qualquer | Todas | Qualquer | 8–26 | 55 dart | 21 |
| Stingray | 180 | Caverna pirata (ilha) | Qualquer | Todas | Qualquer | 18–61 | 80 sinker | 29 |
| Lionfish | 100 | Mar da ilha | Qualquer | Todas | Qualquer | 3–13 | 50 smooth | 19 |
| Blue Discus | 120 | Rios da ilha | Qualquer | Todas | Qualquer | 2–10 | 60 dart | 23 |
| Goby | 150 | Cachoeiras | Qualquer | Todas | Qualquer | 3–13 | 55 dart | 21 |
| Midnight Squid* | 100 | Submarino | — | Inv 15–17 | — | 8–26 | 55 sinker | 21 |
| Spook Fish* | 220 | Submarino | — | Inv 15–17 | — | 8–26 | 60 dart | 23 |
| Blobfish* | 500 | Submarino | — | Inv 15–17 | — | 8–26 | 75 floater | 28 |

\* Peixes do evento Night Market (submarino), ou do canto da praia com isca mágica.

Os peixes de covo e suas chances estão na seção 11.

---

## 15. Depois da pesca: processar e criar

- **Defumador**: peixe + 1 carvão → peixe defumado em 50 min. Vale **2×** o preço, mantém a qualidade e dá 1,5× a energia. Peixe de covo passa a ser comestível.
- **Ovas (roe)**: vêm do viveiro. Valem `30 + preçoBase/2`. Num pote de conserva viram ovas curadas (2× o preço da ova) ou, se forem de esturjão, **caviar** (500).
- **Bait Maker**: peixe → isca direcionada daquele peixe.
- **Viveiro (fish pond)**:
  - Começa com capacidade 3 (alguns peixes raros 1; os lendários no máximo 1). Vai até 10.
  - Os peixes se reproduzem a cada 1 a 5 dias (os mais caros, mais devagar).
  - Ao bater a capacidade, o viveiro pede um item (quest) para aumentar o limite, nas populações 3, 5 e 7. Cada quest dá XP = 20 + 5 × dias de reprodução.
  - Produz ovas (e itens raros quando a população é alta) num balde diário. A chance de produzir sobe com a população.
  - Cada ova extra tem 20% de chance em cadeia, o que dá em média +0,25.
  - Pescar no viveiro tira o peixe sem minigame e não dá XP.
- **Receitas**: sashimi (qualquer peixe) e pratos com buff de pesca.
- **Coleção e conquistas**: guarda o recorde de tamanho e a contagem por peixe. As conquistas são 10 espécies, 24 espécies, 100 peixes e todas as espécies.

---

## 16. Eventos de pesca

- **Trout Derby** (2 dias, rio):
  - O peixe do evento aparece o dia todo, faça o tempo que fizer.
  - Cada captura dele tem **33% × quantidade pescada** de chance de dar uma **etiqueta dourada**.
  - As etiquetas são trocadas no balcão, uma por vez. O 1º prêmio é sempre fixo; depois vem uma sequência de 10 prêmios em ordem fixa, começando num ponto aleatório.
- **SquidFest** (2 dias, praia):
  - Lula o dia todo.
  - O contador de capturas diário fica na tela.
  - Há 4 faixas de prêmio (cobre, ferro, ouro, irídio). No dia 1 são 1, 3, 5 e 8 lulas; no dia 2, 2, 5, 7 e 10. Todos os prêmios são resgatados juntos.
- **Concurso de pesca no gelo** e **minigame da feira**: com tempo cronometrado e sem baú.

---

## 17. Como isso vira o nosso script (resumo para o design)

| Stardew | No `city_fishing` |
|---|---|
| Tabela `Fish` + `Locations` | `config.lua` com peixes (dificuldade, comportamento, tamanho, preço) e **zonas** (`lib.zones`) com lista de spawn, `precedence`, estação, horário (`GetClockHours`), clima (`GetPrevWeatherTypeHashName`) e nível |
| Estação | Mês real, ou um ciclo de estações próprio do servidor |
| Distância da margem | Faixas por zona (píer, costa, mar aberto de barco) ou checagem de água em volta da boia |
| Minigame `BobberBar` | NUI com a física da seção 5 rodando no **cliente**, só como entrada do jogador |
| Escolha do peixe, tamanho, qualidade, XP, baú | **Tudo no servidor** (`docs/standards/security.md`): o servidor sorteia o peixe na fisgada, dá ao cliente só a dificuldade e o comportamento, e confere o resultado (tempo mínimo de minigame plausível, cooldown, distância da água, vara e isca no inventário) |
| Itens (vara, isca, tackle, peixe) | `city_inventory` (`add-item`). Qualidade e tamanho vão em `metadata`. Tackle com `durability` |
| Nível e XP de pesca | Metadata do personagem (`fishing_xp`) e os níveis da seção 10 |
| Profissões | Escolha no nível 5 e no 10, salva em metadata |
| Venda | Peixaria com preço × qualidade × profissão, paga por `city_economy` (adicionar o motivo `fishing-sell` em `sources`) |
| Covo | Prop na água (servidor), resolvido por tempo real em vez de "no dia seguinte" |
| Baú | Tabela de loot no servidor, ponderada pela distância e pelo nível |
| Lendários | Coordenadas exatas, limite por citizenid numa tabela própria |
| Frenesi / bolhas | Evento do servidor: ponto com blip, `GlobalState` e a mesma lógica de bônus |
| Torneios | Eventos com contador por jogador e prêmios por faixa |

Nomes, textos e arte devem ser **nossos**. Dá para usar espécies reais de peixe (são nomes comuns), mas sem as descrições, os ícones ou os nomes inventados do Stardew (Legend, Crimsonfish, etc.).
