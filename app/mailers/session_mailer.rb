class SessionMailer < ApplicationMailer
  def magic_link(user, sign_in_token)
    @user           = user
    @magic_link_url = magic_link_url(token: sign_in_token.token)

    mail(
      to:      @user.email,
      subject: t("mailers.session.magic_link.subject")
    )
  end
end
