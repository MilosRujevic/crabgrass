require File.dirname(__FILE__) + '/../../test_helper'

class People::DirectoryControllerTest < ActionController::TestCase
  fixtures :users, :relationships, :sites, :groups, :memberships

  def setup
  end

  def test_show
    login_as :quentin
    %w(friends peers browse recent).each do |action|
      get :show, :id => action
      assert_response :success
      assert_not_nil assigns(:users)
    end

    get :show, :id => :foo
    assert_permission_denied
  end

  def test_index
    login_as :blue
    get :index
    assert_redirected_to(:action => 'show', :id => :friends)

    login_as :quentin
    get :index
    assert_redirected_to(:action => 'show', :id => :browse)
  end

  def test_friends_with_site_all_profiles_visible
    with_site :test, :all_profiles_visible => true do
      login_as :blue
      get :show, :id => 'friends'
      assert_response :success
      assert_not_nil assigns(:users)
    end
  end

  def test_friends_with_site
    with_site :test, :all_profiles_visible => false do
      login_as :blue
      get :show, :id => 'friends'
      assert_response :success
      assert_not_nil assigns(:users)
    end
  end

end

