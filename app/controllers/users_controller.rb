class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_company!
  before_action :set_user, only: [:destroy, :resend_invite]
  before_action :ensure_same_company!, only: [:destroy, :resend_invite]
  before_action :require_owner!, only: [:destroy, :resend_invite]
  layout "authenticated"

  def index
    @users = current_user.company.users.order(:name, :email)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    @user.company = current_user.company
    @user.role = "member"
    @user.password = SecureRandom.alphanumeric(24)

    if @user.save
      OtpMailer.invite(@user, current_user).deliver_later
      redirect_to users_path, notice: "Convite enviado para #{@user.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def resend_invite
    OtpMailer.invite(@user, current_user).deliver_later
    redirect_to users_path, notice: "Convite reenviado para #{@user.email}."
  end

  def destroy
    if @user == current_user
      redirect_to users_path, alert: "Você não pode remover a si mesmo."
    else
      @user.destroy
      redirect_to users_path, notice: "Usuário removido."
    end
  end

  private

  def set_user
    @user = current_user.company.users.find(params[:id])
  end

  def ensure_same_company!
    redirect_to authenticated_root_path unless @user.company == current_user.company
  end

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
