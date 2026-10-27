# Gamemikle v13

Jogo web estático. A versão 13 inclui:
- 200 raridades novas, cada uma com cinco pets gerados no catálogo (243 raridades e 1.232 pets no total).
- Máquinas de Arena, Fusão, Bónus Global, Trevos, Poções, Loja de Pets e lojas de dados que abrem automaticamente ao aproximar-se.
- Máquina de Atributos com multiplicadores permanentes x2, x100, x10.000, x1.000.000 e x100.000.000.
- Melhorias até 1.000.000.000 de níveis e compras em lotes até 1.000.000.000.
- Atalhos de máquinas removidos do menu para reduzir a quantidade de botões.

## Deploy no Netlify
- Branch de produção: `main`
- Publish directory: `.` (raiz)
- Build command: vazio

O ficheiro principal é `index.html`. O SQL `supabase_v12_setup.sql` é mantido para as funcionalidades online. Se já foi aplicado com sucesso numa versão anterior, não é necessário executá-lo novamente. Nunca incluir chaves secretas do Supabase no HTML público.
