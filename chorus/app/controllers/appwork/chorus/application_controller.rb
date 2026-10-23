module Appwork
  module Chorus
    class ApplicationController < ActionController::Base
      around_action :switch_locale

      private

      # i18n readiness: honor a `?locale=` param against whatever locales the host
      # app has configured, falling back to the default. The engine ships only
      # `en`; the host supplies any additional locales (the dummy adds `es`).
      def switch_locale(&action)
        requested = params[:locale].to_s.to_sym
        locale = I18n.available_locales.include?(requested) ? requested : I18n.default_locale
        I18n.with_locale(locale, &action)
      end

      # Keep the active non-default locale sticky across generated links.
      def default_url_options
        { locale: (I18n.locale == I18n.default_locale ? nil : I18n.locale) }
      end
    end
  end
end
