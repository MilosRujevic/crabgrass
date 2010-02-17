require File.dirname(__FILE__) + '/../../test_helper'
#require 'admin/base_controller'

## Re-raise errors caught by the controller.
##class Admin::BaseController; def rescue_action(e) raise e end; end

class Admin::BaseControllerTest < ActionController::TestCase

  fixtures :users, :sites, :groups, :memberships, :pages

  def setup
    enable_site_testing('unlimited')
  end

  def teardown
    disable_site_testing
  end

  def test_index
    login_as :penguin
    get :index
    assert_response :success
  end

  def test_no_admin
    login_as :red
    assert_permission_denied "only site admins may access the actions." do
      get :index
    end
  end

  def test_no_site
    disable_site_testing
    login_as :penguin
    assert_permission_denied "none of the base actions should be enabled without sites." do
      get :index
    end
  end

end
