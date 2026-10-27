# Gamemikle v13.2

A versão 13.2 mantém as melhorias da v13.1 e ajusta o renascimento:
- O custo inicial continua em 1 bilião de moedas (1e12).
- A cada renascimento, o próximo custo aumenta 10 vezes: 1e12, 1e13, 1e14, 1e15…
- O aumento não para mais no 12.º renascimento.

Inclui também:
- Abreviações curtas para moedas e renda, incluindo a escala vigintilhões (`vig`).
- Cartões de moedas e renda maiores no HUD; fragmentos e trevos mais compactos.
- Máquina de Atributos paga com fragmentos obtidos na Arena.
- Melhoria progressiva de fragmentos e três melhorias finais com custos de 1, 5 e 25 vigintilhões.
- Mais 50 raridades acima da v13, cada uma com cinco pets (250 pets novos).

**Catálogo total:** 293 raridades e 1.482 pets.

## Deploy no Netlify
- Branch de produção: `main`
- Publish directory: `.` (raiz)
- Build command: vazio

O ficheiro principal é `index.html`. O SQL `supabase_v12_setup.sql` é mantido para as funcionalidades online. Se já foi aplicado com sucesso numa versão anterior, não é necessário executá-lo novamente. Nunca incluir chaves secretas do Supabase no HTML público.
