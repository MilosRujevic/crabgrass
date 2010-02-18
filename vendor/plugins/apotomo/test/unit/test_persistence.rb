require File.expand_path(File.dirname(__FILE__) + "/../test_helper")


class PersistenceTest < ActionController::TestCase
  include Apotomo::UnitTestCase
  
  def test_dump
    t = cell(:mouse, :eating, 'mommy')
    
    d = Marshal::dump(t)
    t = Marshal::load(d)
    
    assert_kind_of Apotomo::StatefulWidget, t
  end
  

  
  def test_instance_variable_referencing_between_different_widgets
    m = cell(:master, :set_shared, 'master')
      s = m << cell(:slave, :read_shared, 'slave')
    
    m.controller = @controller
    
    m.invoke
    
    assert_equal m.my_shared.value, "first value"
    assert_state m, :set_shared
    assert_equal s.my_shared.value, "first value"
    assert_state s, :read_shared
    
    
    m = hibernate_widget(m)
    
    
    m.invoke(:reset_shared)
    
    s = m.find_by_id('slave')
    puts s
    assert_equal m.my_shared.value, "second value"
    assert_state m, :reset_shared
    assert_equal s.my_shared.value, "second value"
    assert_state s, :read_shared
  end
  
  def self.before_filter(*args);end
  include Apotomo::ControllerMethods ### TODO: move to UnitTest helper.
  # tests if variable referencing is frozen/thawed correctly, especially if
  # some widget instance var points to a var in session and another widget 
  # updates it, they should both still point to the same object.
  def test_session_variable_referencing
    m = cell(:master, :set_shared_in_session, 'master')
      s = m << cell(:slave, :read_shared, 'slave')
    
    m.controller = @controller
    m.invoke
    
    assert_equal m.find_param(:shared).value, "value from session"
    assert_state m, :set_shared_in_session
    assert_equal s.my_shared.value, "value from session"
    assert_state s, :read_shared
    
    m = hibernate_widget(m)
    puts " --------- new request ---------"
    
    
    s = m.find_by_id('slave')
    s.invoke(:set_shared)
    
    
    
    assert_equal m.find_param(:shared).value, "value from child"
    assert_state m, :set_shared_in_session
    assert_equal s.my_shared.value, "value from child"
    assert_state s, :set_shared
    assert_equal "value from child", controller.session['my_shared'].value    
  end
  
  
  # test if each widget has it's own namespaced session container:
  def test_widget_session_encapsulation
    r = cell(:mouse, :eating, 'root')
      r << a= cell(:mouse, :eating, 'a')
      r << b1= cell(:mouse, :eating, 'b')
        a << b2= cell(:mouse, :eating, 'b')
    
    hibernate_widget(r)
    
    assert_equal session['apotomo_widget_content'].size, 4
  end
  
  # test if removed widgets are removed from the session container:
  def test_widget_session_cleanup
    r = cell(:mouse, :eating, 'root')
      r << a= cell(:mouse, :eating, 'a')
      r << b1= cell(:mouse, :eating, 'b')
        a << b2= cell(:mouse, :eating, 'b')
    
    
    r = hibernate_widget(r)
    
    r.find_by_id('b').removeFromParent!
    
    hibernate_widget(r)
    assert_equal session['apotomo_widget_content'].size, 3
    #assert session['apotomo_widget_content'].reject?('b')
  end
  
  ### ALSO TESTED IN test_jump_to_state.rb#test_brain_reset_when_invoking_a_start_state:
  def test_widget_start_state_cleanup
    r = mouse_mock('root', :start) do
      self.class.transition :in    => :start
      #self.class.transition :from  => :start, :to => :one
      
      def ivar; @ivar; end
      def start
        @ivar = "value"
        render :nothing => true
      end
    end
    
    
    # :start will set a state variable.
    r.invoke
    assert_state r, :start
    assert_equal "value", r.ivar
    
    # if going to a start state, there shouldn't be anything left in the widget.
    r.instance_eval { def start; render :text=>""; end; }
    r.invoke
    assert_state r, :start
    assert_equal nil, r.ivar
  end
  
  # @brain should contain all ivars set during successive state executions.
  def test_brain
    r = mouse_mock('root', :start) do
      self.class.transition :from  => :start, :to => :one
      
      def ivar;   @ivar; end
      def brain;  @brain; end
      def start
        @ivar = "value"
        render :nothing => true
      end
      def one
        @one  = "1"
        render :text => "#{@one}"
      end
    end
    
    # :start will set a state variable.
    r.invoke
    assert_state r, :start
    assert_equal "value", r.ivar
    
    assert_equal ['@ivar'], r.brain
    
    # next, go to :one and set another state variable.
    r.invoke :one
    assert_state r, :one
    assert_equal "value", r.ivar
    assert_equal "1",     r.one
    assert_equal ['@ivar', '@one'], r.brain
    
    # and go back to the start state, flushing the brain and starting over:
    r.invoke
    assert_state r, :start
    assert_equal "value", r.ivar
    assert_equal ['@ivar'], r.brain
  end
  
    
  # @state_view, @rendered_children shouldn't be remembered after state rendering.
  def test_reset_rendering_ivars
    r = mouse_mock('root', :one) do
      def rendered_children; @rendered_children; end
      def one
        @one  = "1"
        render :nothing => true
      end
    end
    
    r.invoke
    assert_state r, :one
    assert r.rendered_children.blank?
  end
  
  
end

class SharedObject
  attr_accessor :value
end

class MasterCell < Apotomo::StatefulWidget
  attr_accessor :my_shared
  
  def transition_map
    {:set_shared => [:reset_shared]}
  end
  
  def set_shared
    @my_shared = SharedObject.new
    @my_shared.value = "first value"
    set_local_param(:shared, @my_shared)
    
    render :view => :widget_content
  end
  
  def reset_shared
    @my_shared.value = "second value"
    
    render :view => :widget_content
  end
  
  def set_shared_in_session
    my_shared = SharedObject.new
    my_shared.value = "value from session"
    session['my_shared'] = my_shared
    
    set_local_param(:shared, session['my_shared'])
    
    render :view => :widget_content
  end
end

class SlaveCell < Apotomo::StatefulWidget
  attr_accessor :my_shared
  
  def transition_map
    {:read_shared => [:read_shared, :set_shared]}
  end
  
  def read_shared
    @my_shared = find_param(:shared)
     
    ""
  end
  
  def set_shared
    @my_shared.value = "value from child"
    ""
  end
end
