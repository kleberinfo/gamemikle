# Gamemikle v12

Jogo web estático para publicação no Netlify a partir do GitHub.

## Deploy automático no Netlify
1. Envie `index.html`, `supabase_v12_setup.sql` e este `README.md` para a raiz da branch `main` deste repositório.
2. No Netlify, abra **Add new site → Import an existing project**.
3. Escolha **GitHub** e selecione `kleberinfo/gamemikle`.
4. Configure **Build command** vazio e **Publish directory** como `.` (raiz do repositório).
5. Confirme o deploy. Cada push na branch configurada poderá disparar um novo deploy.

## Supabase
- Execute o conteúdo de `supabase_v12_setup.sql` no SQL Editor do projeto Supabase.
- Mantenha a autenticação Email ativada para o fluxo atual e desative a confirmação de e-mail se for necessário permitir cadastro sem confirmação.
- O HTML usa apenas URL do projeto e publishable key. Nunca inclua `sb_secret_` ou `service_role` no cliente.

## Arquivos
- `index.html`: jogo Gamemikle v12.
- `supabase_v12_setup.sql`: tabelas e políticas adicionais para perfil, amigos, ranking e trocas.

## Nota
Recursos competitivos e sociais devem ser testados no projeto Supabase real. Não configure segredos de pagamento no HTML público.