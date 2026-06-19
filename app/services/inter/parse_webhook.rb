module Inter
  class ParseWebhook
    include Loggable

    def initialize(payload:)
      @payload = payload
    end

    def parse
      pix_info = @payload.dig('pix', 0)
      raise "Payload de webhook do Inter não contém informações de PIX" unless pix_info.present?

      {
        event_type: 'pix_received', # É o único evento cadastrado por enquanto
        tx_id: pix_info['txid'],
        id_recorrencia: pix_info['idRecorrencia'] || pix_info['idRec'],
        pix_key: pix_info['chave'],
        amount: pix_info['valor'].to_f,
        created_at: pix_info['horario'].to_datetime,
      }
    end
  end
end