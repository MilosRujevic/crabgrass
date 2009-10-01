class BasePage::YuckyPostController < BasePage::SidebarController

  permissions 'admin/moderation'
  permissions 'posts'

  before_filter :login_required

  def show_add
    form_url = {:controller => 'yucky_post', :action => 'add', :post_id => @post.id}
    render :partial => 'base_page/yucky/show_add_popup', :locals => {:form_url => form_url}
  end

  def add
    if params[:flag]
      @rateable.ratings.find_or_create_by_user_id(current_user.id).update_attribute(:rating, YUCKY_RATING)
      @rateable.update_attribute(:yuck_count, @rateable.ratings.with_rating(YUCKY_RATING).count)
      moderateable = ModeratedPost.create(:post_id => params[:post_id], :reason_flagged => params[:reason])
    end      
    close_popup
  end

  def close_popup
    render :template => 'base_page/reset_sidebar'
  end

  protected

  prepend_before_filter :fetch_page
  def fetch_page
    if params[:post_id]
      @post = Post.find_by_id(params[:post_id])
      @rateable = @post
    end
    true
  end

end

