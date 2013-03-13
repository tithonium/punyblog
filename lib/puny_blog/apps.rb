require 'mustache'
require 'hashie/mash'
require 'uri'

module PunyBlog
  class ErrorApp
    def initialize(*args)
      if String === args.first
        @message = args.shift
      elsif Exception === args.first
        @exception = args.shift
        @message = @exception.message
        @backtrace = @exception.backtrace
      end
      if String === args.first
        @submessage = args.shift
      end
      if Array === args.first
        @backtrace = args.shift
      end
    end
    
    def call(env)
      output = if @exception
        "<h1>#{@exception.class.name}</h1><h2>#{@message}</h2>"
      else
        "<h1>#{@message}</h1>"
      end
      output += "<h3>#{@submessage}</h3>" if @submessage
      output += "<pre>" + @backtrace.join("\n") + "</pre>" if @backtrace
      [500, {"Content-Type" => "text/html"}, [output]]
    end
  end
  
  class BlogApp
    def initialize(db)
      @db = db
      Mustache.template_path = File.dirname(__FILE__).sub(%r[/lib.+], '/templates')
    end
    
    def mime_type(filename)
      case filename
      when /\.css$/, :css
        'text/css'
      when /\.gif$/, :gif
        'image/gif'
      when /\.jpg$/, :jpeg, :jpg
        'image/jpg'
      when /\.png$/, :png
        'image/png'
      when /\.svg$/, :svg
        'image/svg+xml'
      when /\.js$/, :js, :javascript
        'application/javascript'
      else
        'application/octet-stream'
      end
    end
    
    def req
      @request || reset_requst
    end
    def reset_request(env = nil)
      @request = Hashie::Mash.new(env: env, cookies: {}, headers: {})
    end
    
    def get_params
      return {} unless req.env['QUERY_STRING']
      @get_params ||= URI.decode_www_form(req.env['QUERY_STRING']).each.with_object(Hashie::Mash.new){|(k,v), h| h[k] ? (h[k]=Array(h[k])) << v : h[k]=v }
    end
    
    def post_body
      @post_body ||= (req.env && req.env["rack.input"] && req.env["rack.input"].read)
    end
    def post_params
      return {} unless post_body
      @post_params ||= URI.decode_www_form(post_body).each.with_object(Hashie::Mash.new){|(k,v), h| h[k] ? (h[k]=Array(h[k])) << v : h[k]=v }
    end
    
    def secured?
      Setting[:username] && Setting[:password]
    end
    
    def site_title; "Marty Angrily Rebukes Stupidity"; end
    def site_short_title; "MARS"; end
    def site_owner; "Martin Tithonium"; end
    
    def title(v=nil);  req.title = v if v  ; req.title || site_title; end
    def layout(v=nil); req.layout = v if v ; req.layout || :layout; end
    
    def status(v=nil); req.status = v if v ; req.status || 200; end
    def type(v=nil);   req.type = v if v   ; req.type || 'text/html' ; end

    def cookie(key, value = nil, ttl = nil)
      ttl = -1 if value.nil?
      req.cookies[key.to_s] = { value: value, ttl: ttl }
    end
    def headers
      req.headers.merge("Content-Type" => type).tap do |h|
        if req.cookies.any?
          h["Set-Cookie"] = req.cookies.collect do |(name,cookie)|
            value = cookie.value
            expiration = cookie.ttl ? (Time.now + cookie.ttl).utc.strftime('%a, %d-%b-%Y %H:%M:%S GMT') : nil
            cookie = "#{name}=#{value}"
            cookie += "; Expires=#{expiration}" if expiration
            cookie
          end.join("\n")
        end
      end
    end
    
    def cookies
      @cookies ||= (req.env['HTTP_COOKIE'] || "").split('; ').each.with_object({}) do |kv, h|
        k, v = kv.split('=', 2)
        v = URI.decode_www_form_component(v)
        h[k] ? (h[k]=Array(h[k])) << v : h[k]=v
      end
    end
    
    def logged_in?
      return true unless secured?
      !!cookies['logged_in']
    end
    
    def output(v=nil)
      req.output ||= []
      req.output << v if v
      req.output.join("\n") unless v
    end
    def raw_output(v)
      req.output = [v]
    end
    
    def render(view, attributes = {})
      template_file = File.join(Mustache.template_path, "#{view}.mustache");
      Mustache.render(IO.read(template_file), attributes)
    end
    
    def pages
      [
        {
          :url => '/',
          :title => 'Latest Posts',
          :current_page => req.current_page == :index
        }
      ].tap do |p|
        unless layout == :bare
          p.concat [
            {
              :url => '/about',
              :title => 'About Me',
              :current_page => req.current_page == :about
            }
          ]
        end
        if logged_in?
          p.concat [
            {
              :url => '/configuration',
              :title => 'Configuration',
              :current_page => req.current_page == :configuration
            },
            {
              :url => '/post',
              :title => 'Post',
              :current_page => req.current_page == :new_post
            },
            {
              :url => '/logout',
              :title => 'Log Out'
            }
          ]
        end
      end
    end
    
    def current_url
      (req.env['PATH_INFO'] + '?' + req.env['QUERY_STRING']).sub(/\?$/, '')
    end
    
    def go_login
      redirect("/login?dest=#{URI.decode_www_form_component(current_url)}")
    end
    def redirect(location = "/")
      [302, headers.merge("Location" => location), []]
    end
    
    def render_output
      case type
      when 'text/html'
        # templates, etc.
        [render(layout,
                "layout_#{layout}" => true,
                body: output,
                site_title: site_title,
                page_title: title,
                recent_posts: recent_posts,
                have_recent_posts: recent_posts.any?,
                have_recent_comments: false,
                copyright_year: "2013-#{Time.now.year}".sub(/^(\d+)-\1$/, '\1'),
                copyright_owner: site_owner,
                pages: pages,
               )]
      else
        [output]
      end
    end
    
    def all_posts(offset = 0, limit = Setting[:items_per_page].to_i)
      req.all_posts_offset = offset
      req.all_posts_limit = limit
      req.first_page = offset == 0 && limit == Setting[:items_per_page].to_i
      req.all_posts ||= PunyBlog::Post.reversed.limit(limit, offset).all
    end
    def recent_posts
      req.recent_posts ||= if req.all_posts && req.first_page
        req.all_posts[0...Setting[:recent_items_count].to_i]
      else
        PunyBlog::Post.recent.all
      end
    end
    def current_post
      req.current_post ||= begin
        if req.current_post_id
          PunyBlog::Post[id: req.current_post_id]
        elsif req.current_post_date
          PunyBlog::Post[created_at: req.current_post_date]
        end
      end
    end
    
    def call(env)
      $site_root = "http://#{env['HTTP_HOST']}"
      start_time = Time.now
      reset_request(env)
      cookie(:last_request, Time.now.to_f)
      
      case env['PATH_INFO']
      when %r[^/?$], %r[^/(\d+)$]
        req.current_page = :index
        req.page_num = ($1 || 1).to_i
        req.post_count = Post.count
        limit = Setting[:items_per_page].to_i
        req.page_count = (req.post_count / limit.to_f).ceil.to_i
        offset = (req.page_num - 1) * limit
        req.all_posts_offset = offset
        req.all_posts_limit = limit
        pagination = (1..req.page_count).collect do |p|
          {
            :num => p,
            :url => p == 1 ? '/' : "/#{p}",
            :current => p == req.page_num
          }
        end
        output render(:index, posts: all_posts(offset, limit),
                              pagination: pagination,
                              previous_page: req.page_num > 1 ? (req.page_num == 2 ? '/' : "/#{req.page_num-1}") : nil,
                              next_page: req.page_num < req.page_count ? "/#{req.page_num+1}" : nil
                     )
      when %r[^/\d{4}/\d{2}/\d{2}/(\d+)-[^/]+$]
        req.current_page = :post
        # /1234-post-title-here
        req.current_post_id = $1.to_i
        title "#{site_short_title} - #{current_post.title}"
        output render(:post, current_post)
      # when %r[^/(\d{4})(\d{2})(\d{2})/(\d{2})(\d{2})(\d{2})/[^/]+$]
      #   req.current_page = :post
      #   # /20130101/123456/post-title-here
      #   req.current_post_date = Time.utc($1, $2, $3, $4, $5, $6)
      #   title "#{site_short_title} - #{current_post.title}"
      #   output render(:post, current_post)
      when %r[^/about$]
        req.current_page = :about
        title "About #{site_short_title}"
        output "<p>Your bones don't break, mine do. That's clear. Your cells react to bacteria and viruses differently than mine. You don't get sick, I do. That's also clear. But for some reason, you and I react the exact same way to water. We swallow it too fast, we choke. We get some in our lungs, we drown. However unreal it may seem, we are connected, you and I. We're on the same curve, just on opposite ends. </p>\n\n<p>Normally, both your asses would be dead as fucking fried chicken, but you happen to pull this shit while I'm in a transitional period so I don't wanna kill you, I wanna help you. But I can't give you this case, it don't belong to me. Besides, I've already been through too much shit this morning over this case to hand it over to your dumb ass. </p>\n<p>Do you see any Teletubbies in here? Do you see a slender plastic tag clipped to my shirt with my name printed on it? Do you see a little Asian child with a blank expression on his face sitting outside on a mechanical helicopter that shakes when you put quarters in it? No? Well, that's what you see at a toy store. And you must think you're in a toy store, because you're here shopping for an infant named Jeb. </p>" * 2
      when %r[^/login$]
        req.current_page = :login
        if env['REQUEST_METHOD'] == 'POST'
          if post_params.username? || post_params.password?
            if post_params.username == Setting[:username] &&
               post_params.password == Setting[:password]
              cookie(:logged_in, true, 3600)
              return redirect(post_params.destination || '/')
            else
              req.error = "Bad username or password"
            end
          else
            req.error = "Did you forget something?"
          end
        end
        req.layout = :bare
        title "#{site_short_title} - Log in"
        output render(:login, error: req.error, warning: req.warning, notice: req.notice, destination: get_params.dest)
      when %r[^/logout$]
        cookie(:logged_in, nil)
        return redirect
      when %r[^/configuration$]
        return go_login unless logged_in?
        req.current_page = :configuration
        valid_settings = [:username, :password, :site_title, :site_short_title, :site_owner, :items_per_page, :recent_items_count]
        if env['REQUEST_METHOD'] == 'POST'
          req.notice = "Changes saved."
          begin
            Setting.db.transaction do
              post_params.each do |k, v|
                next unless valid_settings.include?(k.to_sym)
                Setting.for(k).update(value: v)
              end
            end
          rescue => ex
            req.error = "Failed to save: #{ex.message}"
            req.notice = nil
          end
          unless secured?
            req.warning = "You have still not secured the site. Please set both Username and Password."
          end
        end
        req.layout = :bare
        title "#{site_short_title} - Configuration"
        settings = valid_settings.collect{|k| Setting.for(k) }
        output render(:configuration, settings: settings, error: req.error, warning: req.warning, notice: req.notice)
      when %r[^/post$]
        return go_login unless logged_in?
        if env['REQUEST_METHOD'] == 'POST'
          begin
            post = Post.create([:title, :body].each.with_object({}){|k,h| h[k] = post_params[k] })
            return redirect(post.url)
          rescue => ex
            req.error = "Failed to save: #{ex.message}"
          end
        end
        req.current_page = :new_post
        req.layout = :bare
        title "#{site_short_title} - New Post"
        output render(:editor, error: req.error, warning: req.warning, notice: req.notice)
      when %r[^/debug$]
        req.current_page = :debug
        type 'text/plain'
        title "#{site_short_title} - Debug"
        output "Hello world!"
        output env.inspect
        output @db.tables.inspect
      else
        filename = env['PATH_INFO'].sub(%r[^/], '')
        if File.exists?(filename)
          type mime_type(filename)
          raw_output(IO.read(filename))
        else
          title "#{site_short_title} - Page Not Found"
          output "<h1>Not Found</h1>"
          output "The requested path (<kbd>#{filename}</kbd>) could not be found."
        end
      end
      
      finish_time = Time.now
      STDERR.puts %Q[#{env['REQUEST_METHOD']} #{env['PATH_INFO']} #{'%.3f' % ((finish_time-start_time)*1000.0)}ms]
      
      [status, headers, render_output]
    end
  end
end
