require File.dirname(__FILE__) + '/../../test_helper'

class Groups::DirectoryControllerTest < ActionController::TestCase
  fixtures :users, :groups, :memberships

  def setup
  end

  def test_index
    get :index
    assert_redirected_to(:action => 'search')

    login_as :blue
    get :index
    assert assigns(:groups)
    assert_redirected_to(:action => 'my')

    login_as :quentin
    get :index
    assert_redirected_to(:action => 'search')    
  end

  def test_recent
    login_as :blue

    get :recent
    assert assigns(:groups).include?(groups(:recent_group))
  end

  def test_my_groups
    groups(:warm).add_user! users(:kangaroo)
    assert !users(:kangaroo).member_of?(groups(:rainbow))

    login_as :kangaroo
    get :my
    assert_response :success
    assert_not_nil assigns(:groups)
    assert assigns(:groups).include?(groups(:warm)), 'should display committee even though it is a committee, because we are not a member of the parent'
  end

#  def test_directory
#    login_as :gerrard
#    get :directory
#    assert_response :success
#    assert_not_nil assigns(:groups)
#  end

#  def test_directory_letter
#    login_as :blue
#    get :directory, :letter => 'r'
#    assert_response :success
#    assert_equal 1, assigns(:groups).size
#    assert_equal "rainbow", assigns(:groups)[0].name
#  end

end

