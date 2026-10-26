# Gamemikle v12.3

Correção da interação da mochila no menu lateral:
- Clicar em **MOCHILA** não fecha automaticamente o menu da direita.
- O inventário abre por cima do menu, mantendo a navegação na posição elevada.
- Ao fechar o inventário, o menu permanece visualmente estável.

## Deploy no Netlify
- Branch de produção: `main`
- Publish directory: `.` (raiz)
- Build command: vazio

O ficheiro principal é `index.html`. O SQL do Supabase é mantido como referência; se já foi aplicado com sucesso na v12, não é necessário executá-lo novamente. Nunca incluir chaves secretas do Supabase no HTML público.
