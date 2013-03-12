require 'mustache'

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
        'appliation/javascript'
      else
        'application/octet-stream'
      end
    end
    
    def status(v=nil); @status = v if v ; @status || 200; end
    def type(v=nil); @type = v if v ; @type || 'text/html' ; end
    def output(v=nil)
      @output ||= []
      @output << v if v
      @output.join("\n") unless v
    end
    def raw_output(v)
      @output = [v]
    end
    
    def render(view, attributes)
      template_file = File.join(Mustache.template_path, "#{view}.mustache");
      Mustache.render(IO.read(template_file), attributes)
    end
    
    def pages
      [
        {
          :url => '/',
          :title => 'Latest Posts',
          :current_page => @current_page == :index
        },
        {
          :url => '/about',
          :title => 'About Me',
          :current_page => @current_page == :about
        }
      ]
    end
    
    def render_output
      case type
      when 'text/html'
        # templates, etc.
        [render(:layout,
                body: output,
                site_title: "...",
                page_title: "...",
                recent_posts: recent_posts,
                have_recent_posts: recent_posts.any?,
                have_recent_comments: false,
                copyright_year: "2013-#{Time.now.year}".sub(/^(\d+)-\1$/, '\1'),
                pages: pages,
               )]
      else
        [output]
      end
    end
    
    def all_posts
      @all_posts ||= PunyBlog::Post.reversed.all
    end
    def recent_posts
      @recent_posts ||= if @all_posts
        @all_posts[0...PunyBlog::Post::RECENT_LIMIT]
      else
        PunyBlog::Post.recent.all
      end
    end
    def current_post
      @current_post ||= PunyBlog::Post[@current_post_id] if @current_post_id
      @current_post ||= PunyBlog::Post[created_at: @current_post_date] if @current_post_date
    end
    
    def call(env)
      # "PATH_INFO"=>"/asdfasdf"}
      # "REQUEST_URI"=>"http://localhost:9393/asdfasdf?asdfads",
      # "QUERY_STRING"=>"asdfads",
      
      case env['PATH_INFO']
      when %r[^/?$]
        @current_page = :index
        output render(:index, posts: all_posts)
      when %r[^/(\d+)-[^/]+$]
        @current_page = :post
        # /1234-post-title-here
        @current_post_id = $1
        output render(:post, current_post)
      when %r[^/(\d{4})(\d{2})(\d{2})/(\d{2})(\d{2})(\d{2})/[^/]+$]
        @current_page = :post
        # /20130101/123456/post-title-here
        @current_post_date = Time.utc($1, $2, $3, $4, $5, $6)
        output render(:post, current_post)
      when %r[^/about$]
        @current_page = :about
        5.times do
          output "<p>Your bones don't break, mine do. That's clear. Your cells react to bacteria and viruses differently than mine. You don't get sick, I do. That's also clear. But for some reason, you and I react the exact same way to water. We swallow it too fast, we choke. We get some in our lungs, we drown. However unreal it may seem, we are connected, you and I. We're on the same curve, just on opposite ends. </p>\n\n<p>Normally, both your asses would be dead as fucking fried chicken, but you happen to pull this shit while I'm in a transitional period so I don't wanna kill you, I wanna help you. But I can't give you this case, it don't belong to me. Besides, I've already been through too much shit this morning over this case to hand it over to your dumb ass. </p>
\n<p>Do you see any Teletubbies in here? Do you see a slender plastic tag clipped to my shirt with my name printed on it? Do you see a little Asian child with a blank expression on his face sitting outside on a mechanical helicopter that shakes when you put quarters in it? No? Well, that's what you see at a toy store. And you must think you're in a toy store, because you're here shopping for an infant named Jeb. </p>"
end
      when %r[^/debug$]
        @current_page = :debug
        type 'text/plain'
        output "Hello world!"
        output env.inspect
        output @db.tables.inspect
      else
        filename = env['PATH_INFO'].sub(%r[^/], '')
        if File.exists?(filename)
          type mime_type(filename)
          raw_output(IO.read(filename))
        else
          output "<h1>Not Found</h1>"
          output "The requested path (<kbd>#{filename}</kbd>) could not be found."
        end
      end
      
      [status, {"Content-Type" => type}, render_output]
    end
  end
end
