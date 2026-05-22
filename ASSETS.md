# Assets necessários para a Landing Page

Estes são os placeholders usados na landing page (`app/views/pages/home.html.erb`) que precisam ser substituídos por assets reais.

---

## 1. Foto do depoimento (Seção "Prova de confiança")

**Onde:** Seção de prova social, card de depoimento
**Formato:** JPG ou PNG, proporção quadrada (ex: 200×200px), rosto centralizado
**Tamanho exibido:** 40×40px (circular)
**Descrição:** Foto de um cliente real que usa a plataforma. Expressão amigável, fundo neutro ou levemente desfocado.
**Arquivo sugerido:** `public/testimonials/maria_s.jpg`
**Como usar na view:** Substituir o `<div>` com ícone `ph-user` por:
```erb
<%= image_tag "testimonials/maria_s.jpg", class: "w-10 h-10 rounded-full object-cover flex-shrink-0", alt: "Maria S." %>
```

---

## 2. Nome e cargo do depoimento

**Onde:** Abaixo da foto no card de depoimento
**Atualmente:** "Maria S." / "Proprietária de academia"
**Substituir por:** Nome real e função do cliente (com permissão).
**Nota:** Pode ser um primeiro nome + inicial do sobrenome para preservar privacidade.

---

## 3. Texto do depoimento

**Onde:** Corpo do card de depoimento
**Atualmente:** *"Antes eu esquecia de cobrar clientes toda semana. Hoje sai tudo automático pelo WhatsApp e eu nem preciso abrir o celular."*
**Substituir por:** Depoimento real de um cliente, coletado via WhatsApp, e-mail ou formulário.
**Dicas:**
- Máximo 2-3 frases
- Deve mencionar o problema que tinha antes e o resultado depois
- Tom casual/espontâneo converte melhor que texto polido demais

---

## 4. Número de cobranças enviadas (Seção "Prova de confiança")

**Onde:** Card de destaque azul com número grande
**Atualmente:** `+500`
**Substituir por:** Número real de cobranças disparadas pela plataforma.
**Como atualizar:** Editar a linha em `home.html.erb`:
```erb
<p class="text-5xl font-extrabold tracking-tight">+500</p>
```
**Sugestão de milestones para atualizar:** +500 → +1.000 → +5.000 → +10.000

---

## 5. (Opcional) Screenshot do dashboard

**Onde:** Pode ser adicionado na seção "Como funciona" ou como elemento de suporte na seção Hero.
**Formato:** PNG, largura mínima 1200px, fundo claro
**Descrição:** Print da tela principal do dashboard mostrando a lista de clientes com status de pagamento — transmite que a interface é limpa e organizada.
**Arquivo sugerido:** `public/screenshots/dashboard.png`
**Nota:** Borrar ou remover dados reais de clientes antes de publicar.

---

## 6. (Opcional) Logo de parceiros / integrações

**Onde:** Pode ser adicionado abaixo do Hero como "barra de logos"
**Exemplos:** Logo do WhatsApp Business, etc.
**Nota:** Verificar termos de uso dos logos antes de publicar.
