require 'paperclip'

Paperclip.interpolates :account_id do |attachment, style|
  attachment.instance.account_id
end

