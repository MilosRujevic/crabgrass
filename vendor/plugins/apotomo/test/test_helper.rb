require File.expand_path(File.dirname(__FILE__) + '/../../../../test/test_helper')

Cell::Base.view_paths.unshift File.expand_path(File.dirname(__FILE__) + "/fixtures")

class MouseCell < Apotomo::StatefulWidget
  def eating; render; end
end

class RenderingTestCell < Apotomo::StatefulWidget
  attr_reader :brain
  attr_reader :rendered_children
  
  
  
  def jump
    jump_to_state :check_state
  end
end


class UrlMockController < ActionController::Base
  include Apotomo::ControllerMethods
  
  def controller;self;end
  
  def rescue_action(e) raise e end
  
  def index; render :text => ""; end
  
  def url_for(options)
    url         =  "http://www.apotomo.de/"
    action      = options[:action]      || :drink
    controller  = options[:controller]  || :beers
    
    url << "#{controller}/#{action}"
    
    return url unless options
    
    options.delete(:only_path)
    options.delete(:controller)
    options.delete(:action)        
    
    url << "?" + options.sort{|a,b| a.to_s <=> b.to_s}.collect {|e| "#{e.first}=#{e.last}"}.join("&") unless options.blank?
    url
  end
end

module Apotomo::UnitTestCase
  
  attr_accessor :controller, :session
  
  # allow people to set up trees within test methods, with shortcuts.
  include Apotomo::WidgetShortcuts
  
  
  def setup
    @controller = UrlMockController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @controller.request   = @request
    @controller.response  = @response
    @controller.params    = {}
    @controller.session   = @session = {}
  end
  
  
  # session/request simulation --------------------------------------------------
  def self.class_inheritable_array(*args);end
  def self.has_widgets_blocks=(*args);end
  def self.before_filter(*args);end
  include Apotomo::ControllerMethods ### TODO: move neccessary methods to Persistance module.
  
  
  # Simulate a request-cycle end and the start of a new request. The tree is returned  
  # exactly as if there had been a new request and Rails handled the session thawing.
  def hibernate_widget(widget)
    session['apotomo_widget_content'] = {}
    widget.freeze_instance_vars_to_storage(session['apotomo_widget_content'])
    session['apotomo_root'] = widget
    
    widget = Marshal.load(Marshal.dump(session))['apotomo_root']
    widget.thaw_instance_vars_from_storage(session['apotomo_widget_content'])
    widget.controller = @controller
    widget
  end
  
  def apotomo_root_mock
    widget('apotomo/stateful_widget', :widget_content, '__root__')
  end
  
  
  # assertions ------------------------------------------------------------------
  
  def assert_selekt(content, *args, &block)
    assert_select(HTML::Document.new(content).root, *args, &block)
  end
  
  # Assert the <tt>widget</tt> is in <tt>state</tt>.
  def assert_state(widget, state)
    assert_equal state, widget.last_state
  end
  
  # Assert that an event of <tt>type</tt> and with <tt>source_id</tt> was triggered
  # and catched by at least one EventHandler.
  def assert_event(type, source_id)
    actions = Apotomo::EventProcessor.instance.queue
    assert actions.find{|a| a.last.type == type and a.last.source.name == source_id}
  end
  
  # test utils ------------------------------------------------------------------
  
  # Creates the test root widget and sets it in @controller.apotomo_root for you.
  def init_apotomo_root_mock!
    r = apotomo_root_mock
    r.root.controller = @controller
    @controller.instance_eval do
      @apotomo_root = r
    end
  end
  
  # Provides a ready-to-use mouse widget instance.
  def mouse_mock(id='mouse', start_state=:eating, opts={}, &block)
    mouse = mouse_class_mock.new(id, start_state, opts)
    mouse.instance_eval &block if block_given?
    mouse.controller = @controller
    mouse
  end
  
  def mouse_class_mock(&block)
    klass = Class.new(MouseCell)
    klass.instance_eval &block if block_given?
    klass
  end
  
  def re(str)
    Regexp.new(Regexp.escape(str))
  end
  
end
