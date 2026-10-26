# Gamemikle v12.3

Correção da mochila no menu lateral: ao clicar em **MOCHILA**, o menu da direita não se fecha automaticamente; o inventário abre por cima dele. Ao fechar o inventário, a navegação continua na posição elevada.

## Deploy no Netlify
- Branch de produção: `main`
- Publish directory: `.` (raiz)
- Build command: vazio

O ficheiro principal é `index.html`. O SQL do Supabase é mantido como referência; se já foi aplicado com sucesso na v12, não é necessário executá-lo novamente. Nunca incluir chaves secretas do Supabase no HTML público.
