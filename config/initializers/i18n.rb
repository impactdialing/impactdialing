Rails.application.config.i18n.default_locale = :en
Rails.application.config.i18n.fallbacks      = [:en]

if Rails.env.test? || Rails.env.development?
  # https://robots.thoughtbot.com/foolproof-i18n-setup-in-rails
  module ActionView::Helpers::TranslationHelper
    def t_with_raise(*args)
      value = t_without_raise(*args)

      if value.to_s.match(/\Atranslation missing: (.+)/)
        raise "Translation missing: #{$1}"
      else
        value
      end
    end
    alias_method :translate_with_raise, :t_with_raise

    alias_method_chain :t, :raise
    alias_method_chain :translate, :raise
  end

  module I18n
    def self.t(*args)
      value = super(*args)

      if value.to_s.match(/\Atranslation missing: (.+)/)
        raise "Translation missing: #{$1}"
      else
        value
      end
    end
  end
end