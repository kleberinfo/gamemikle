# Gamemikle v13.1

A versão 13.1 traz:
- Abreviações curtas para moedas e renda, incluindo a escala vigintilhões (`vig`).
- Cartões de moedas e renda maiores no HUD; fragmentos e trevos mais compactos.
- Máquina de Atributos paga com fragmentos obtidos na Arena.
- Melhoria progressiva de fragmentos e três melhorias de endgame com custos em vigintilhões.
- Mais 50 raridades acima da v13, cada uma com cinco pets (250 pets novos).

## Deploy no Netlify
- Branch de produção: `main`
- Publish directory: `.` (raiz)
- Build command: vazio

O ficheiro principal é `index.html`. O SQL `supabase_v12_setup.sql` é mantido para as funcionalidades online. Se já foi aplicado com sucesso numa versão anterior, não é necessário executá-lo novamente. Nunca incluir chaves secretas do Supabase no HTML público.
