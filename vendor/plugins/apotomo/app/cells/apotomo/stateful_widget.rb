# (c) 2008-2009, Nick Sutterer <apotonick@gmail.com>
module Apotomo
  # The StatefulWidget is the core component in Apotomo. Any widget is derived from 
  # this class.
  #
  # === Widgets are mini-controllers
  # Widgets are derived cells[http://cells.rubyforge.org/rdoc], meaning they basically
  # look and behave like super-fast mini-controllers known from Rails. State actions in 
  # a widget are like controller actions - they implement the business logic in a method
  # and can render a corresponding view.
  # Instance variables from the widget are passed to the state view, which is
  # automatically found by convention: view filename and state method usually have the
  # same name. Use <tt>render :view => my_view</tt> to rendero alternative views.
  # 
  # You can plug multiple of these "mini-controllers" into a page, and you can even make
  # one widget contain others. The modeling currently happens in the WidgetTree.
  #
  # === Widgets are state machines
  # States can be connected to model a workflow. For example, a form widget could have
  # one state for diplaying an empty form, one state showing the filled-out form 
  # with messages at invalid fields, and one state showing a success message after the
  # form had valid input.
  # 
  # To send a widget - from outside - into a certain state, you usually #invoke a
  # state. Initial start states are defined in #new. Valid transitions are defined in
  # #transition_map and you can jump to an arbitrary state by calling #jump_to_state
  # inside a state method.
  #
  # When a widget changes its state, it automatically updates the respective part in the
  # page.
  # 
  # === Widgets are stateful
  # After a state transition a widget restores the last environment it was in. So you
  # have all the instance variables back that have been there when the state method
  # finished. You no longer are aware of requests, rather think in a persistent
  # environment.
  # 
  # === Widgets are event-driven
  # Unlike in traditional rails, widgets are not updated by requests 
  # directly, but by events. Events usually get triggered by form submits using 
  # ViewHelper#form_to_event, by clicking links or by real GUI events (as a 
  # <tt>onChange</tt> event in Javascript which you map to an Apotomo event with 
  # ViewHelper#address_to_event).
  # 
  # Widgets can also fire events internally using EventAware#trigger.
  # Listeners that handle an event are attached with EventAware#watch.
  
  # The brain
  # collects ivars set during state execution(s), even in successive state jumps.
  # brain content is exposed to view and unset when hitting a start state.
  # If you want to set an everlasting ivar which survives a start state, set it before
  # #render_content_for_state, best place is the constructor.
  
  class StatefulWidget < Cell::Base
    
    class_inheritable_array :initialize_hooks, :instance_writer => false
    self.initialize_hooks = []
    
    attr_accessor :opts ### DISCUSS: don't allow this, rather introduce #visible?.
    
    include TreeNode
    include EventMethods   ### TODO: set a "see also" link in the docs.
    include Transitions
    include Caching
    
    include DeepLinkMethods
    
    helper Apotomo::ViewHelper
    
    
    attr_writer :controller
    attr_reader :last_brain
        
    # Constructor which needs a unique id for the widget and one or multiple start states.
    # <tt>start_state</tt> may be a symbol or an array of symbols.    
    def initialize(id, start_states=:widget_content, opts={})
      @opts         = opts  # was: super(controller, opts)
      @name         = id
      @start_states = start_states.kind_of?(Array) ? start_states : [start_states]

      @child_params = {}
      @visible      = true
      @version      = 0
      @ivars_before = nil
      @invoke_block = nil
      
      @brain        = []        # ivars set during state execution(s).
      @cell         = self
      @state_name   = nil
      
      process_initialize_hooks(id, start_states, opts)
    end
    
    def process_initialize_hooks(*args)
      self.class.initialize_hooks.each { |h| send(h, *args) }
    end
    
    def last_state
      @state_name
    end


    # Defines the instance vars that should <em>not</em> survive between requests, 
    # which means they're not frozen in Apotomo::StatefulWidget#freeze.
    def ivars_to_forget
      unfreezeable_ivars
    end
    
    def unfreezeable_ivars
      ['@childrenHash', '@children', '@parent', '@controller', '@cell', '@invoke_block', '@ivars_before', '@rendered_children']
    end

    # Defines the instance vars which should <em>not</em> be copied to the view.
    # Called in Cell::Base.
    def ivars_to_ignore
      (instance_variables - ivars_to_expose)
    end
    
    # Defines the ivars which should be copied to and accessable in the view.
    def ivars_to_expose
      @brain + ['@rendered_children']
    end

    #--
    # don't thaw when
    #   - parent explicitly invokes a start state
    #   - in F5 context (*)
    #   - in init context (*)
    # the is_f5_fixme flag is needed for context propagation when children are rendered.
    # this is a part i don't like.
    #--
    # Central entry point for starting the FSM and recursively executing the respective
    # state method and rendering its view. The invoke'd widget will call #invoke
    # for each visible child, per default.
    # See #invoke_state.
    
    ### DISCUSS: state is input in FSM speech, or event.
    def invoke(input=nil, &block)
      @invoke_block = block ### DISCUSS: store block so we don't have to pass it 10 times?
      logger.debug "\ninvoke on #{name} with #{input.inspect}"
      
      ### TODO: remove the * propagation.
      if input.to_s == "*"
        @is_f5_fixme = true
        input= start_state_for_state(last_state)
        logger.debug "F5, going back to #{input}"
      end
      
      process_input(input)
    end
    
    # Initiates the rendering cycle of the widget:
    # - if <tt>state</tt> isn't a start state, the environment of the widget is restored
    #   using #thaw.
    # - find the next valid state (usually this should be the passed <tt>state</tt>).
    # - executes the respective state method for <tt>state</tt> 
    #   (per default also named <tt>state</tt>)
    # - invoke the children
    # - render the view for the state (per default named after the state method)
    def process_input(input)
      state = input
      unless start_state?(input)
        state = find_next_state_for(last_state, input)
      end 
      

      
      invoke_state(state)
    end
    
    # Returns the rendered content for the widget by running the state method for <tt>state</tt>.
    # This might lead us to some other state since the state method could call #jump_to_state.
    ### DISCUSS: should be public.
    def invoke_state(state)
      logger.debug "#{name}: transition: #{last_state} to #{state}"
      logger.debug "                                    ...#{state}"
      
      ### DISCUSS: at this point, we finally know the concrete next state.
      ### this is the next state we go to, all prior references to state where input.
      ### #render_state really means what it does: we processed the input symbol, checked the condition and now go to the new state (which produces output).
      
      flush_brain if start_state?(state)
      @ivars_before = instance_variables
      
      render_state(state)
    end
    
    
    # called in Cell::Base#render_state
    def dispatch_state(state)
      send(state, &@invoke_block)
    end
    
    
    # Render the view for the current state. Usually called at the end of a state method.
    #
    # ==== Options
    # * <tt>:view</tt> - Specifies the name of the view file to render. Defaults to the current state name.
    # * <tt>:template_format</tt> - Allows using a format different to <tt>:html</tt>.
    # * <tt>:layout</tt> - If set to a valid filename inside your cell's view_paths, the current state view will be rendered inside the layout (as known from controller actions). Layouts should reside in <tt>app/cells/layouts</tt>.
    # * <tt>:html_options</tt> - Pass a hash to add html attributes like +class+ or +style+ to the widgets' surrounding div.
    # * <tt>:js</tt> - Executes the string as JavaScript on the page. If set, no view will be rendered.
    # * <tt>:invoke</tt> - Explicitly define the state to be invoked on a child when rendering.
    #
    # Example:
    #  class MouseCell < Apotomo::StatefulWidget
    #    def eating
    #      # ... do something
    #      render 
    #    end
    #
    # will just render the view <tt>eating.html</tt>.
    # 
    #    def eating
    #      # ... do something
    #      render :view => :bored, :layout => "metal"
    #    end
    #
    # will use the view <tt>bored.html</tt> as template and even put it in the layout
    # <tt>metal</tt> that's located at <tt>$RAILS_ROOT/app/cells/layouts/metal.html.erb</tt>.
    #
    #  render :js => "alert('SQUEAK!');"
    #
    # issues a squeaking alert dialog on the page.
    #
    #  render :html_options => {:class => :highlighted}
    # will result in
    #  <div id="mouse" class="highlighted"...>
    def render(opts={})
      state = @state_name
      
      logger.debug @brain.inspect
      logger.debug "state ivars:"
      @brain |= (instance_variables - @ivars_before)
      logger.debug @brain.inspect
      
      
      ### DISCUSS: provide a better JS abstraction API and de-coupled helpers like #visual_effect.
      ### DISCUSS: move to Cell::Base?
      if content = opts[:js]
        return ActiveSupport::JSON::Variable.new(content)
      end
      
      
      
      
      
      if content = opts[:text]
        return content
      end
      if opts[:nothing]
        return "" 
      end
      
      
      ### TODO: test :render_children => false
      rendered_children = render_children_for(state, opts)
      
      
      ### FIXME: we need to expose @controller here for several helper method. that sucks!
      @controller =root.controller
      
      html_options = opts[:html_options] || {} ### DISCUSS: move to #defaultize_render_options_for.
      html_options[:id] ||= name
      
      
      opts[:locals] = prepare_locals_for(opts[:locals], rendered_children)
      
      
      content = render_view_for(opts, state)
      #content = render_view_for(content, state)  # defined in Cell::Base.
      
      frame_content_for(content, html_options)
      
      
    end
    
    def prepare_locals_for(locals, rendered_children)
      locals ||= {}
      locals = {:rendered_children => rendered_children}.merge(locals)
    end

    # Wrap the widget's current state content into a div frame.
    def frame_content_for(content, html_options)
      ### TODO: i'd love to see a real API for helpers in rails.
      Object.new.extend(ActionView::Helpers::TagHelper).content_tag(:div, content, html_options)
    end
    

    # Force the FSM to go into <tt>state</tt>, regardless whether it's a valid 
    # transition or not.
    ### TODO: document the need for return.
    ### TODO: document that there is no state check or brain erase.
    def jump_to_state(state)
      logger.debug "STATE JUMP! to #{state}"
      
      render_state(state)
    end
    
    
    def children_to_render
      children.find_all { |w| w.visible? }
    end

    def render_children_for(state, opts)
      rendered_children  = ActiveSupport::OrderedHash.new
      
      children_to_render.each do |cell|
        child_state = decide_child_state_for(cell, opts[:invoke])
        logger.debug "    #{cell.name} -> #{child_state}"
        
        rendered_children[cell.name] = render_child(cell, child_state)
      end
      
      return rendered_children
    end

    def render_child(cell, state)
     cell.invoke(state)
    end

    def decide_child_state_for(child, invoke_opts)
      invoke_opts ||= {}
      next_state    = nil
      next_state    = "*" if @is_f5_fixme
      
      invoke_opts.stringify_keys[child.name.to_s] || next_state
    end
    
    
    # is only called when the whole page is reloaded (F5).
    def render_content &block
      invoke("*", &block)
    end
    
    
    ### TODO: discuss the need for recursive params?
    def set_local_param(param, value)
      @child_params[param] = value  ### needed for #param.
    end
    
    # Retrieve the param value for child. This parameter has to be explicitly set 
    # with #set_child_param prior to this call.
    def local_param(param)
      @child_params[param]
    end
    
    
    ### DISCUSS: use #param only for accessing request data.
    def param(name)
      params[name]
    end
    
    ### DISCUSS: use #find_param to retrieve objects from ascendents.
    def find_param(name)
      local_param(name) || parent.find_param(name)
    end

    #--
    ### addressing/utilities ------------------------------------------------------
    #--
    
    # This is called when a bookmarkable link is calculated. Every widget on the path
    # from the targeted to root can insert state recovery information in the address
    # by overriding #local_address.
    def address(way={}, target=self, state=nil)
    #def address(way=HashWithIndifferentAccess.new, target=self, state=nil)
      way.merge!( local_address(target, way, state) )
      
      #logger.debug "address: #{name}"
      #logger.debug way.inspect

      return way if isRoot?

      return parent.address(way, target)
    end
    
      
    # Override this if the widget needs to set state recovery information for a 
    # bookmarkable link.
    # Must return a Hash with the local state recovery information.
    def local_address(target, way, state)
      {}
    end

    def find_by_id(widget_id)
      return find {|node| node.name.to_s == widget_id.to_s}
    end
    
    def find_widget(widget_id)
      root.find_by_id(widget_id)
    end
    
    
    
    
    def controller
      return @controller if isRoot?
      root.controller
    end
    
    # Sets the widget to invisible, which will usually suppress executing the 
    # state method and rendering. Apparently the same applies to all children 
    # of this widget.
    def invisible!; @visible = false; end
    # Sets the widget to visible (default).
    def visible!;   @visible = true; end
    # Returns if visible.
    def visible?;   @visible; end
    
    
    def createDumpRep
      strRep = String.new
      strRep << @name.to_s << @@fieldSep << self.class.to_s << @@fieldSep << (isRoot? ? @name.to_s : @parent.name.to_s)
      
      ###@ strRep << @@fieldSep << dump_instance_variables << @@recordSep
      strRep << @@recordSep
    end
  
  #--
  ### DISCUSS: taking the path as key slightly blows up the session.
  #--
  def freeze_instance_vars_to_storage(storage)
    #logger.debug "freezing in #{path}"
    storage[path] = {}  ### DISCUSS: check if we overwrite stuff?
    (self.instance_variables - ivars_to_forget).each do |var|
      storage[path][var] = instance_variable_get(var)
      #logger.debug "  #{var}: #{storage[path][var]}"
    end
    
    children.each { |ch| ch.freeze_instance_vars_to_storage(storage) }
  end
  def thaw_instance_vars_from_storage(storage)
    #logger.debug "thawing in #{path}"
    storage[path].each do |k, v|
      instance_variable_set(k, v)
      #logger.debug "  set #{k}: #{v}"
    end
    
    children.each { |ch| ch.thaw_instance_vars_from_storage(storage) }
  end
  
  
  def flush_brain
    @brain.each do |var|
      remove_instance_variable(var)
    end
    @brain.clear
  end

  def _dump(depth)
      strRep = String.new
      each {|node| strRep << node.createDumpRep}
      strRep
  end
  
    def self._load(str)
      ### TODO: fix multiple loading issue.
      #@@load_count ||= 0
      #@@load_count+=1
      #raise "too much loading" if @@load_count > 1
      
      loadDumpRep(str)
    end
    def self.loadDumpRep(str)
      nodeHash = Hash.new
      rootNode = nil
      str.split(@@recordSep).each do |line|
        
          ###@ name, klass, parent, content_str = line.split(@@fieldSep)
          name, klass, parent = line.split(@@fieldSep)
          #logger.debug "thawing #{name}->#{parent}"
          currentNode = klass.constantize.new(name)
          
          ###@ Marshal.load(content_str).each do |k,v|
          ###@   ###@ logger.debug "setting "+k.inspect
          ###@   currentNode.instance_variable_set(k, v)
          ###@ end
          
          nodeHash[name] = currentNode
          if name != parent  # Do for a child node
              nodeHash[parent].add(currentNode)
          else
              rootNode = currentNode
          end
      end
      rootNode
  end
  end

end
