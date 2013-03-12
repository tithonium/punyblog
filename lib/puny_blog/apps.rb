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
    
    def status(v=nil); @status = v if v ; @status || 200; end
    def type(v=nil); @type = v if v ; @type || 'text/html' ; end
    def output(v=nil)
      @output ||= []
      @output << v if v
      @output.join("\n")
    end
    
    def render(view, attributes)
      template_file = File.join(Mustache.template_path, "#{view}.mustache");
      Mustache.render(IO.read(template_file), attributes)
    end
    
    def render_output
      case type
      when 'text/html'
        # templates, etc.
        [render(:layout,
                body: output,
                page_title: "...",
                recent_posts: recent_posts)]
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
      # "REQUEST_PATH"=>"/asdfasdf"}
      # "REQUEST_URI"=>"http://localhost:9393/asdfasdf?asdfads",
      # "QUERY_STRING"=>"asdfads",
      
      case env['REQUEST_PATH']
      when %r[^/?$]
        output render(:index, posts: all_posts)
      when %r[^/(\d+)-[^/]+$]
        # /1234-post-title-here
        @current_post_id = $1
        output render(:post, current_post)
      when %r[^/(\d{4})(\d{2})(\d{2})/(\d{2})(\d{2})(\d{2})/[^/]+$]
        # /20130101/123456/post-title-here
        @current_post_date = Time.utc($1, $2, $3, $4, $5, $6)
        output render(:post, current_post)
      when %r[^/debug$]
        type 'text/plain'
        output "Hello world!"
        output @db.tables.inspect
      else
        output "<h1>Not Found</h1>"
        output "The requested path (<kbd>#{env['REQUEST_PATH']}</kbd>) could not be found."
      end
      
      [status, {"Content-Type" => type}, render_output]
    end
  end
end
