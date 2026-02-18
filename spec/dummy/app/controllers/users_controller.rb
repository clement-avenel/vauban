# frozen_string_literal: true

class UsersController < ApplicationController
  # Simple controller to switch the current user for demo purposes
  # In a real app, this would be handled by authentication

  def switch
    user_id = params[:user_id]
    if user_id.present?
      user = User.find_by(id: user_id)
      if user
        session[:demo_user_id] = user.id
        redirect_back(fallback_location: root_path, notice: "Switched to #{user.name || user.email}")
      else
        redirect_back(fallback_location: root_path, alert: "User not found")
      end
    else
      redirect_back(fallback_location: root_path, alert: "No user selected")
    end
  end
end
