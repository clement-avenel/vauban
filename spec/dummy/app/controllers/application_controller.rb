class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes if respond_to?(:stale_when_importmap_changes)
  
  # Include Vauban authorization helpers (conditional to handle loading order)
  include Vauban::Rails::ControllerHelpers if defined?(Vauban::Rails)
  
  # Handle Vauban authorization errors
  rescue_from Vauban::Unauthorized do |exception|
    redirect_to root_path, alert: "You are not authorized to perform this action."
  end
  
  # Dummy current_user method for demo/testing
  # In a real app, this would come from authentication (Devise, etc.)
  def current_user
    @current_user ||= if session[:demo_user_id]
      User.find_by(id: session[:demo_user_id]) || User.first
    else
      User.first
    end
  end
  helper_method :current_user
end
