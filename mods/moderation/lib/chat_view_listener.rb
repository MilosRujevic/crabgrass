class ChatViewListener < Crabgrass::Hook::ViewListener
  include Singleton

  def chat_message_actions(context)
    message = context[:message]
    if !logged_in?
      return
    elsif message.sender == current_user
      return
    elsif message.level == "sys"
      return
    elsif message.deleted_at
      return content_tag :strong, "Deleted"[:deleted]
    else
      #
      # WOW: THIS IS GOING TO BE INCREDIBLY SLOW
      #
      rating = message.ratings.find_by_user_id(current_user.id)
      if rating.nil? or rating.rating != YUCKY_RATING
        if current_user.moderator?(current_site)
          icon = 'trash'
          link_name = 'move message to trash'[:trash_message]
          confirm = nil
        else
          icon = 'sad_plus'
          link_name = :flag_inappropriate.t
          confirm = :confirm_inappropriate_page.t
          success = nil
        end
        url = url_for(:controller => 'yucky', :chat_message_id => message.id, :action => :add)
        return link_to_remote_with_icon(
          link_name, {:url => url, :confirm => confirm}, {:icon => icon, :class => 'shy'}
        )
        #content_tag(:span, link, :class => "shy", :id => "flag-#{context[:message].id}"})
      elsif rating.rating == YUCKY_RATING
        url = url_for(:controller => 'yucky', :chat_message_id => message.id, :action => :remove)
        return link = link_to_remote_with_icon(
          :flag_appropriate.t, {:url => url}, {:icon => 'sad_minus', :class => 'shy'}
        )
        #content_tag(:span, link, {:class => 'small_icon sad_minus_16 shy', :id => "flag-#{context[:message].id}"})
      end
    end
  end

end
