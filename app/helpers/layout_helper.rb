module LayoutHelper

  ##########################################
  # DISPLAYING BREADCRUMBS and CONTEXT
  
  def link_to_breadcrumbs
    if @breadcrumbs and @breadcrumbs.length > 1
      content_tag(:div, @breadcrumbs.collect{|b| content_tag(:a, b[0], :href => b[1])}.join(' &raquo; '), :id => 'breadcrumbs')
    else
      ""
    end
  end
  
  def first_breadcrumb
    @breadcrumbs.first.first if @breadcrumbs.any?
  end
 
  def first_context
    @context.first.first if @context.any?
  end

  #########################################
  # TITLE
  
  def title_from_context
    (
      [@html_title] +
      (@context||[]).collect{|b|truncate(b[0])}.reverse +
      [site_name]
    ).compact.join(' - ')
  end

  def site_name
   (@site||Site.new(:name => 'unknown')).name
  end
      
  ###########################################
  # STYLESHEET
  
  # custom stylesheet
  # rather than include every stylesheet in every request, some stylesheets are 
  # only included if they are needed. a controller can set a custom stylesheet
  # using 'stylesheet' in the class definition, or an action can set @stylesheet.
  def optional_stylesheet_tag
    sheets = [controller.class.stylesheet, @stylesheet].flatten.compact.collect{|i| 'as_needed/' + i}
    stylesheet_link_tag(*sheets)
  end 
 
  # crabgrass_stylesheets()
  # this is the main helper that is in charge of returning all the needed style
  # elements for HTML>HEAD. There are five (5!) types of stylings:
  #
  # (1) default crabgrass stylesheets (for core things like layout)
  # (2) theme_styles (core css, but for making things pretty).
  # (3) optional stylesheets (these are stylesheets that are loaded on a
  #     per-controller or per-action basis.
  # (4) context styles (style changes based on context)
  # (5) content_for :style (inline styles set in the views)
  # (6) mod styles (so that mods can insert their own styles after everthing else)

  def crabgrass_stylesheets
    lines = []
    lines << stylesheet_link_tag(
      'core/reset',
      'core/design',
      'core/landing',
      'core/page',
      'core/ui_elements',
      'core/wiki',
      'core/images',
      :cache => 'core'
    )
    lines << stylesheet_link_tag('icon_png')
    lines << optional_stylesheet_tag
    lines << '<style type="text/css">'
    lines << context_styles
    lines << @content_for_style
    lines << '</style>'
    lines << '<!--[if IE 6]>'
    lines << stylesheet_link_tag('ie/ie6')
    lines << stylesheet_link_tag('icon_gif')
    lines << '<![endif]-->'
    lines << '<!--[if IE 7]>'
    lines << stylesheet_link_tag('ie/ie7')
    lines << stylesheet_link_tag('icon_gif')
    lines << '<![endif]-->'
    lines << mod_styles
    lines.join("\n")
  end

  # to be overridden by mods, if they want.
  def mod_styles
    ""
  end
  def favicon_link
    %q[<link rel="shortcut icon" href="/favicon.ico" type="image/x-icon" />
<link rel="icon" href="/favicon.png" type="image/x-icon" />]
  end

  # support for holygrail layout:
  
  # returns the style elements need in the <head> for the holygrail layouts. 
  def holygrail_stylesheets
    lines = []
    lines << stylesheet_link_tag('holygrail/common')
    lines << stylesheet_link_tag('holygrail/' + type_of_column_layout)
    lines << '<!--[if lt IE 7]>
<style media="screen" type="text/css">.col1 {width:100%;}</style>
<![endif]-->' # this line is important!
    lines.join("\n")
  end

  def type_of_column_layout
    @layout_type ||= if @left_column.any? and @right_column.any?
      'three'
    elsif !@left_column.any? and !@right_column.any?
      'one'
    elsif @left_column.any?
      'left'
    elsif @right_column.any?
      'right'
    end
  end
  
  ############################################
  # JAVASCRIPT

  def optional_javascript_tag
    js_files = optional_javascripts
    js_files = [js_files] unless js_files.is_a? Array
    return unless js_files.any?
    extra = js_files.delete(:extra)
    js_files = js_files.collect{|file| "as_needed/#{file}" }
    if extra
      js_files += ['effects', 'dragdrop', 'controls']
    end
    javascript_include_tag(*js_files)
  end
  def optional_javascripts
    if @javascript  # optional javascript at the action level
      @javascript
    else # optional javascript at the controller level
      controller.class.javascript 
    end
  end
  
  def crabgrass_javascripts
    lines = []
    lines << javascript_include_tag('prototype', 'application', :cache => true)
    lines << optional_javascript_tag
    lines << '<!--[if lt IE 7.]>'
      # make 24-bit pngs work in ie6
      lines << '<script defer type="text/javascript" src="/javascripts/ie/pngfix.js"></script>'
      # prevent flicker on background images in ie6
      lines << '<script>try {document.execCommand("BackgroundImageCache", false, true);} catch(err) {}</script>'
    lines << '<![endif]-->'
    lines.join("\n")
  end
  
  ############################################
  # BANNER

  # banner stuff
  def banner_style
    "background: #{@banner_style.background_color}; color: #{@banner_style.color};" if @banner_style
  end  
  def banner_background
    @banner_style.background_color if @banner_style
  end
  def banner_foreground
    @banner_style.color if @banner_style
  end

  ############################################
  # CONTEXT STYLES
  
  def background_color
    "#ccc"
  end
  def background
    #'url(/images/test/grey-to-light-grey.jpg) repeat-x;'
    'url(/images/background/grey.png) repeat-x;'
  end

  # return all the custom css which might apply just to this one group
  def context_styles
    style = []
     if @banner
       style << '#banner {%s}' % banner_style
       style << '#banner a.name_link {color: %s; text-decoration: none;}' %
                banner_foreground
       style << '#topmenu li.selected span a {background: %s; color: %s}' %
                [banner_background, banner_foreground]
     end
    style.join("\n")
  end

  ###########################################
  # LAYOUT STRUCTURE

  # builds and populates a table with the specified number of columns
  def column_layout(cols, items)
    lines = []
    count = items.size
    rows = (count.to_f / cols).ceil
    lines << '<table>'
    for r in 1..rows
      lines << ' <tr>'
      for c in 1..cols
         cell = ((r-1)*cols)+(c-1)
         next unless items[cell]
         lines << "  <td valign='top'>"
         lines << '  %s' % items[cell]
         #lines << "r%s c%s i%s" % [r,c,cell]
         lines << '  </td>'
      end
      lines << ' </tr>'
    end
    lines << '</table>'
    lines.join("\n")
  end

end
