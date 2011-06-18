class GalleryController < BasePageController

  stylesheet 'gallery'
  javascript :extra, 'page'
  permissions 'gallery'

  include GalleryHelper
  include BasePageHelper
  include ActionView::Helpers::JavascriptHelper


  verify :method => :post, :only => [:add, :remove]

  def show
    @images = paginate_images
    #@cover = @page.cover
  end

  def comment_image
    @image = @page.images.find(params[:id])
    @post = Post.build(:page => @image.page,
                       :user => current_user,
                       :body => params[:post][:body])
    current_user.updated(@image.page)
    @post.save!
    redirect_to page_url(@page,
                         :action => 'detail_view',
                         :id => @image.id)
  end


  def add_star
    @image = @page.images.find(params[:id])
    @image.page.add(current_user, :star => true).save!
    if request.xhr?
      render :text => javascript_tag("$('add_star_link').hide();$('remove_star_link').show();"), :layout => false
    else
      redirect_to page_url(@page, :action => 'detail_view', :id => @image.id)
    end
  end


  def remove_star
    @image = @page.images.find(params[:id])
    @image.page.add(current_user, :star => false).save!
    if request.xhr?
      render :text => javascript_tag("$('remove_star_link').hide();$('add_star_link').show();"), :layout => false
    else
      redirect_to page_url(@page, :action => 'detail_view', :id => @image.id)
    end
  end

  def detail_view
    @showing = @page.showings.find_by_asset_id(params[:id], :include => 'asset')
    @image = @showing.asset
    @image_index = @showing.position
    @next = @showing.lower_item
    @previous = @showing.higher_item

    # we need to set @upart manually as we are not working on @page
    @upart = @image.page.participation_for_user(current_user)

    # the discussion for the detail view is not the discussion of the gallery,
    # it is attached to the asset's hidden page:
    @discussion = @image.page.discussion rescue nil
    @discussion ||= Discussion.new
    @create_post_url = url_for(:controller => 'gallery', :action => 'comment_image', :id => @image.id)
    load_posts()
  end

  def change_image_title
    if request.post?
      # whoever may edit the gallery, may edit the assets too.
      raise PermissionDenied unless current_user.may?(:edit, @page)
      @image = @page.images.find(params[:id])
      page = @image.page
      page.title = params[:title]
      current_user.updated(page)
      page.save!
      redirect_to page_url(@page, :action => 'detail_view', :id => @image.id)
    end
  end

  def edit
    @images = paginate_images
  end

  def make_cover
    unless current_user.may?(:admin, @page)
      if request.xhr?
        render(:text => I18n.t(:you_are_not_allowed_to_do_that),
               :layout => false) and return
      else
        raise PermissionDenied
      end
    end
    asset = Asset.find_by_id(params[:id])

    @page.cover = asset
    current_user.updated(@page)
    @page.save!

    if request.xhr?
      render :text => I18n.t(:album_cover_changed), :layout => false
    else
      flash_message(I18n.t(:album_cover_changed))
      redirect_to page_url(@page, :action => 'edit')
    end
  rescue ArgumentError # happens with wrong ID
    raise PermissionDenied
  end

  def find
    existing_ids = @page.image_ids
    @images = Asset.visible_to(current_user, @page.group).exclude_ids(existing_ids).media_type(:image).most_recent.paginate(:page => params[:page])
  rescue => exc
    flash_message :exception => exc
    redirect_to :action => 'show', :page_id => @page.id
  end

  def sort
    ids = params[:sort_gallery]
    debugger
  end

  def update_order
    if params[:images]
      text =""
      ActiveSupport::JSON::decode(params[:images]).each do |image|
        showing = @page.showings.find_by_asset_id(image['id'].to_i)
        showing.insert_at(image['position'].to_i)
      end
    else
      showing = @page.showings.find_by_asset_id(params[:id])
      new_pos = (params[:direction] == 'left') ? showing.position - 1 :
        showing.position + 1
      new_pos = @page.showings.size-1 if new_pos < 0
      new_pos = 0 if new_pos > new_pos.size-1
      showing.insert_at(new_pos)
    end
    current_user.updated(@page)
    if request.xhr?
      render :text => I18n.t(:order_changed), :layout => false
    else
      flash_message_now I18n.t(:order_changed)
      redirect_to(:controller => 'gallery',
                  :action => 'edit',
                  :page_id => @page.id)
    end
  rescue => exc
    render :text => I18n.t(:error_saving_new_order_message) %{ :error_message => exc.message}
  end

  def add
    asset = Asset.find(params[:id])
    @page.add_image!(asset, current_user, params[:position])
    if request.xhr?
      render :layout => false
    else
      redirect_to page_url(@page)
    end
  #rescue Exception => exc
  #  flash_message_now :exception => exc
  end

  def upload
    if request.xhr?
      render :layout => false
    elsif request.post?
      params[:assets].each do |file|
        next if file.size == 0
        asset = Asset.create_from_params(:uploaded_data => file)
        @page.add_image!(asset, current_user)
      end
      redirect_to page_url(@page)
    end
  end

  def upload_zip
    if request.get?
      redirect_to page_url(@page)
    elsif request.post? && params[:zipfile]
      @assets, @failures = Asset.make_from_zip(params[:zipfile])
      @assets.each do |asset|
        @page.add_image!(asset, current_user)
      end
      redirect_to page_url(@page)
    else
      render :update do |page|
        page.replace_html 'target_for_upload', :partial => 'upload_zip'
      end
    end
  end

  def remove
    asset = Asset.find(params[:id])
    @page.remove_image!(asset)
    if request.xhr?
      undo_link = undo_remove_link(params[:id], params[:position])
      js = javascript_tag("remove_image(#{params[:id]});")
      render(:text => I18n.t(:successfully_removed_image, :undo_link => undo_link) + js,
             :layout => false)
    else
      redirect_to page_url(@page)
    end
  end

  protected

  def setup_view
    @image_count = @page.images.size if @page
    @show_right_column = true
    if !action?(:show) && @page
      @title_addendum = render_to_string(:partial => 'back_link')
    end
    if action?(:detail_view)
      @discussion = false # disable load_posts()
      @show_posts = true
   end
  end

  def build_page_data
    @assets ||= []
    params[:assets].each do |file|
      next if file.size == 0 # happens if no file was selected
      build_asset_data(@assets, file)
    end
    if params[:asset] and params[:asset][:zipfile] and params[:asset][:zipfile].size != 0
      build_zip_file_data(@assets, params[:asset][:zipfile])
    end

    # gallery page has no 'data' field
    return nil
  end

  def build_asset_data(assets, file)
    asset = Asset.create_from_params(:uploaded_data => file) do |asset|
      asset.parent_page = @page
    end
    @assets << asset
    @page.add_image!(asset, current_user)
    asset.save!
  end

  def build_zip_file_data(assets, file)
    zip_assets, failures = Asset.make_from_zip(file)
    zip_assets.each do |asset|
      asset.parent_page = @page
      @assets << asset
      @page.add_image!(asset, current_user)
      asset.save!
    end
  end

  def destroy_page_data
    @assets.compact.each do |asset|
      asset.destroy unless asset.new_record?
      asset.page.destroy if asset.page and !asset.page.new_record?
    end
  end

  #
  # there appears to be a bug in will_paginate. it only appears when
  # doing two inner joins and there are more records than the per_page size.
  #
  # unfortunately, this is what we need for returning the images the current
  # user has access to see.
  #
  # This works as expected:
  #
  #   @page.images.visible_to(current_user).find(:all)
  #
  # That is just great, but we also want to paginate. This blows up horribly,
  # if there are more than three images:
  #
  #  @page.images.visible_to(current_user).paginate :page => 1, :per_page => 3
  #
  # So, this method uses two queries to get around the double join, so that
  # will_paginate doesn't freak out.
  #
  # The first query just grabs all the potential image ids (@page.image_ids)
  #
  def paginate_images
    params[:page] ||= 1
    Asset.visible_to(current_user).paginate(:page => params[:page], :conditions => ['assets.id IN (?)', @page.image_ids])
  end

end

