# a Feature is a resource
# this is a CRUD controller for Features resources
# a Feature resource is modeled as a GroupParticipation object with 'static' property
class Groups::FeaturesController < Groups::BaseController
  permissions 'groups/requests'

  javascript 'effects', 'dragdrop', 'controls', 'autocomplete' # require for find page autocomplete
  helper 'groups'
  before_filter :fetch_data, :login_required
  before_render :load_features

  # verify AJAX
  verify :xhr => true, :except => :index, :redirect_to => {:action => :index}

  # verify HTTP verbs
  verify :only => :create, :method => :post, :redirect_to => {:action => :index}
  verify :only => :destroy, :method => :delete, :redirect_to => {:action => :index}
  verify :only => :update, :method => :put, :redirect_to => {:action => :index}

  def index
    @second_nav = 'administration'
    @third_nav = 'settings'
  end

  def create
    # find the participation that joins this group to the selected page
    # and feature if
    participation = @group.participations.find_by_page_id(params[:page_id])
    participation.feature!
  end

  def destroy
    participation = @group.participations.find_by_id(params[:feature_id])
    participation.unfeature!
  end

  def update
    feature_ids = params[:features_ids].collect(&:to_i)
    # instead of trusting the featured ids
    # we will only update the participations which belong to this group
    current_features = @group.participations.featured
    # iterate through the ids in the original order
    feature_ids.each_with_index do |id, position|
      # find the feature with this id
      feature = current_features.detect {|f| f.id == id}
      feature.update_attribute(:featured_position, position) if feature
    end
  end

  def auto_complete
    like_query = "#{params[:query]}%"
    pages = Page.find_by_path(['text',params[:query]], options_for_group(@group))
    render :json => {
      :query => params[:query],
      :suggestions => pages.collect(&:title),
      :data => pages.collect(&:id)
    }
  end

  protected

  def load_features
    @features = @group.participations.featured.with_pages
  end

  def fetch_data
    # must have a group
    @group = Group.find_by_name(params[:id])
  end

  def context
    group_settings_context
  end

  def authorized?
    may_edit_featured_pages?
  end

end
