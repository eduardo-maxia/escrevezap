# Exemplos de Uso dos Serviços do Banco Inter

## 📋 Resumo

O serviço do Banco Inter foi refatorado para usar um cliente autenticado que gerencia tokens automaticamente. Agora o código está mais limpo e reutilizável.

## 🏗️ Arquitetura

- **Client**: Cliente base que gerencia autenticação SSL e tokens OAuth
- **InterService**: Serviços de negócio (webhook, PIX, extrato)
- **PixService**: Interface simplificada para uso comum

## 🚀 Como Usar

### 1. Gerar Cobrança PIX Simples
```ruby
# Cobrança de R$ 25,50
charge = PixService.generate_simple_charge(25.50)

puts "TxID: #{charge['txid']}"
puts "QR Code: #{charge['qrcode']}"
puts "Copia e Cola: #{charge['pixCopiaECola']}"
```

### 2. Gerar Cobrança com CPF
```ruby
charge = PixService.generate_charge_with_cpf(
  amount: 100.00,
  cpf: "12345678901",
  name: "João Silva",
  description: "Restauração de 5 fotos"
)
```

### 3. Verificar Webhook
```ruby
webhook_info = PixService.check_webhook
puts "Webhook URL: #{webhook_info['webhookUrl']}"
puts "Chave PIX: #{webhook_info['chave']}"
```

### 4. Registrar Novo Webhook
```ruby
PixService.register_webhook("https://meusite.com/webhook/inter")
```

### 5. Consultar PIX Recebidos
```ruby
# PIX do mês atual
pix_list = PixService.get_received_pix

# PIX de um período específico
pix_list = PixService.get_received_pix(
  start_date: "2025-10-01T00:00:00Z",
  end_date: "2025-10-31T23:59:59Z",
  page: 1,
  per_page: 50
)

puts "PIX encontrados: #{pix_list['pix'].length}"
```

### 6. Consultar Extrato Bancário
```ruby
# Extrato do mês atual
statement = PixService.get_bank_statement

# Extrato de um período específico
statement = PixService.get_bank_statement(
  start_date: "2025-10-01",
  end_date: "2025-10-31"
)

puts "Transações: #{statement['transacoes'].length}"
```

### 7. Teste Completo da Integração
```ruby
result = PixService.test_integration

if result[:success]
  puts "✅ Integração funcionando!"
  puts "Webhook: #{result[:webhook]['webhookUrl']}"
  puts "Teste de cobrança: #{result[:test_charge]['txid']}"
else
  puts "❌ Erro: #{result[:error]}"
end
```

## 🔧 Uso Avançado com Client

Se precisar de controle mais granular, pode usar o `Client` diretamente:

```ruby
# Cliente para leitura de PIX
client = Client.for_pix_read
response = client.get("/pix/v2/pix", {
  inicio: "2025-10-01T00:00:00Z",
  fim: "2025-10-31T23:59:59Z"
})

# Cliente para cobrança
client = Client.for_cob_write
response = client.put("/pix/v2/cob/#{txid}", {
  calendario: { expiracao: 3600 },
  valor: { original: "10.00" },
  chave: "sua-chave-pix"
})
```

## 🎯 Funcionalidades do Cliente

- ✅ **Gerenciamento Automático de Token**: Renova automaticamente quando expira
- ✅ **Autenticação SSL**: Usa certificados automaticamente
- ✅ **Cache de Token Persistente**: Salva tokens em arquivos para reutilização entre execuções
- ✅ **Prevenção de Rate Limiting**: Evita regeneração desnecessária de tokens
- ✅ **Logging Detalhado**: Logs de debug e erro
- ✅ **Tratamento de Erro**: Exceptions específicas para diferentes tipos de erro
- ✅ **Múltiplos Escopos**: Clientes específicos para cada tipo de operação
- ✅ **Limpeza Automática**: Remove tokens expirados na inicialização da aplicação

## 📱 Interface Web de Teste

Acesse `/inter/test` para uma interface web completa para testar todas as funcionalidades.

## ⚙️ Configuração Necessária

Certifique-se de que os certificados estão no local correto:
- `python_inter/certificado.crt`
- `python_inter/api_key.key`

## 🔐 Escopos Disponíveis

- `webhook.read` - Consultar webhooks
- `webhook.write` - Registrar/alterar webhooks
- `cob.write` - Criar cobranças PIX
- `pix.read` - Consultar PIX recebidos
- `extrato.read` - Consultar extrato bancário

## 🏪 Gerenciamento de Cache de Tokens

O sistema agora inclui cache persistente de tokens OAuth para evitar rate limiting:

### Comandos Rake Disponíveis

```bash
# Listar todos os tokens em cache
rake inter:tokens:list

# Limpar todos os tokens
rake inter:tokens:clear_all

# Limpar apenas tokens expirados
rake inter:tokens:clear_expired

# Limpar token de um escopo específico
rake inter:tokens:clear_scope SCOPE=webhook.read

# Ver informações de um token
rake inter:tokens:info SCOPE=pix.read

# Verificar status de todos os escopos
rake inter:tokens:check_all

# Testar geração de tokens para todos os escopos
rake inter:tokens:test_generation
```

### Localização do Cache

Os tokens são salvos em: `tmp/inter_tokens/`
- Cada escopo tem seu próprio arquivo: `{scope}_token.json`
- Arquivos incluem token, data de expiração e metadados
- Diretório é automaticamente incluído no `.gitignore`

### Gerenciamento Programático

```ruby
# Listar tokens em cache
TokenManager.list_cached_tokens

# Limpar tokens expirados
TokenManager.clear_expired_tokens

# Ver info de um token específico
TokenManager.token_info('pix.read')

# Verificar status de todos os escopos
TokenManager.check_all_scopes_status
```

### Comportamento Automático

- **Na inicialização**: Tokens expirados são automaticamente removidos
- **Durante uso**: Tokens válidos são carregados do cache
- **Ao expirar**: Novos tokens são gerados e salvos automaticamente
- **Rate limiting**: Evitado ao reutilizar tokens válidos entre execuções