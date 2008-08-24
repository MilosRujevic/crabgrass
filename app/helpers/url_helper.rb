module UrlHelper
  # if you pass options[:full_name] = true, committees will have the string
  # "group+committee" (default does not include leading "group+")
  # 
  # options[:display_name] = true for groups will yield the descriptive name for display, if one exists
  #
  # This function accepts a string, a group_id (integer), or a class derived from a group
  #
  # If options[:text] = "boop %s beep", the group name will be 
  # substituted in for %s, and the display name will be "boop group_name beep"
  #
  # If options[:action] is not included it is assumed to be show, and otherwise
  # the the link goes to "/groups/action/group_name'
  def name_and_path_for_group(arg,options={})
    if arg.instance_of? Integer
      # this assumes that at some point simple id based finds will be cached in memcached
      arg = Group.find(arg)
    end

    if arg.instance_of? String
      name = arg
    elsif arg.is_a? Committee
      name = arg.name
      if options[:full_name]
        display_name = arg.full_name
      else
        display_name = arg.display_name
      end
    elsif arg.is_a? Group
      name = arg.name
      if options[:display_name]
        display_name = arg.display_name
      end
    end
    display_name ||= name
    display_name = options[:text] % display_name if options[:text]
    action = options[:action] || 'show'
    if action == 'show'
      path = "/#{name}"
    else
      path = "/groups/#{action}/#{name}"
    end
    [display_name, path]  
  end

  def url_for_group(arg, options={})
    display_name, path = name_and_path_for_group(arg,options)
    path
  end

  # arg might be a user object, a user id, or the user's login
  def login_and_path_for_user(arg, options={})
    if arg.is_a? Integer
      # this assumes that at some point simple id based finds will be cached in memcached
      user = User.find(arg)
      login = user.login 
      display = user.display_name
    elsif arg.is_a? String
      login = arg
      display = arg
    elsif arg.is_a? User
      login = arg.login
      display = arg.display_name
    end
    #link_to login, :controller => '/people', :action => 'show', :id => login if login
    action = options[:action] || 'show'
    if action == 'show'
      path = "/#{login}"
    else
      path = "/person/#{action}/#{login}"
    end
    [login, path, display]
  end
  
  def url_for_user(arg, options={})
    login, path, display = login_and_path_for_user(arg,options)
    path
  end
  
  # creates a link to a user, with or without the avatar.
  # avatars are displayed as background images, with padding
  # set on the <a> tag to make room for the image.
  # accepts:
  #  :avatar => [:small | :medium | :large]
  #  :label -- override display_name as the link text
  #  :style -- override the default style
  #  :class -- override the default class of the link (name_link)
  def link_to_user(arg, options={})
    login, path, display_name = login_and_path_for_user(arg,options)
    style = options[:style]                         # allow style override
    label = options[:login] ? login : display_name  # use display_name for label by default
    label = options[:label] || label                # allow label override
    klass = options[:class] || 'name_link'
    avatar = ''
    if options[:avatar_as_separate_link] # not used for now
      avatar = link_to(avatar_for(arg, options[:avatar], options), :style => style)
    elsif options[:avatar]
      size = Avatar.pixels(options[:avatar])[0..1].to_i
      padding = size/5 + size
      url = avatar_url(:id => (arg.avatar||0), :size => options[:avatar])
      if style
        style = "background-image: url(#{url});" + style
      else
        padding = size/5 + size
        style = "background: url(#{url}) no-repeat 0% 50%; padding: 4px 0 4px #{padding}px;"
      end
    end
    avatar + link_to(label, path, :class => klass, :style => style)
  end

  # see function name_and_path_for_group for description of options
  def link_to_group(arg, options={})
    if arg.is_a? Integer
      @group_cache ||= {}
      # hacky fix for error when a page persists after it's group is deleted --af
      if not @group_cache[arg]
        if Group.exists?(arg)
          @group_cache[arg] = Group.find(arg)
        else
          return ""
        end
      end
      # end hacky fix
      arg = @group_cache[arg]
    end
    
    display_name, path = name_and_path_for_group(arg,options)
    style = options[:style]
    label = options[:label] || display_name
    klass = options[:class] || 'name_link'
    avatar = ''
    if options[:avatar_as_separate_link] # not used for now
      avatar = link_to(avatar_for(arg, options[:avatar], options), :style => style)
    elsif options[:avatar]
      size = Avatar.pixels(options[:avatar])[0..1].to_i
      padding = size/5 + size
      if arg and arg.avatar
        url = avatar_url(:id => (arg.avatar||0), :size => options[:avatar])
      else
        url = avatar_url(:id => 0, :size => options[:avatar])
      end
      if style
        style = "background-image: url(#{url})" + style
      else
        padding = size/5 + size
        style = "background: url(#{url}) no-repeat 0% 50%; padding-left: #{padding}px"
      end
    end
    avatar + link_to(label, path, :class => klass, :style => style)
  end

  def url_for_entity(entity, options={})
    if entity.is_a? User
      url_for_user(entity, options)
    elsif entity.is_a? Group
      url_for_group(entity, options)
    end
  end

  ##
  ## TAGGING
  ##

  def tag_link(tag, group_name=nil, user_name=nil)
    name = CGI.escape tag.name
    if group_name  
      link_path = "/groups/tags/#{group_name}/#{name}"
    elsif user_name 
      link_path = "/people/tags/#{user_name}/#{name}"
    else
      link_path = "/me/search/tag/#{name}"
    end
    link_to h(tag.name), link_path

  end

end
