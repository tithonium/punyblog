require 'yaml'
require 'logger'
require 'sequel/core'
require 'sequel/model'

module PunyBlog
  module Database
    
    def self.db ; @db ; end
    def self.app ; @app ; end
    
    unless File.exists?("config/database.yml")
      open("config/database.yml", "w") do |fp|
        fp.puts "---\n:adapter: mysql\n:host: db.example.com\n:database: my_blog\n:user: user\n:password: drowssap\n"
      end
      STDERR.puts "failed to find config"
      @app = ErrorApp.new("No database configuration. Please edit config/database.yml")
    end
    
    begin
      @db_config = YAML.load(IO.read("config/database.yml"))
      # @db_config[:logger] = Logger.new($stderr)
      @db = Sequel.connect @db_config
      Sequel::Model.plugin :timestamps
    rescue => ex
      STDERR.puts "failed to connect to db"
      @app = ErrorApp.new(ex, "Unable to connect to database. Please check the configuration.")
    end
    
    begin
      @db.create_table(:posts, charset: 'utf8') do
        primary_key :id
        String :title, :index => true, :null => false
        text   :body, :null => false
        Time   :created_at, :null => false
        String :image, :null => true
      end unless @db.tables.include?(:posts)
      unless @db.tables.include?(:settings)
        @db.create_table(:settings, charset: 'utf8') do
          String :key,   :index => true,  :null => false, :primary_key => true
          String :value, :index => false, :null => false
        end
        # @db[:settings].insert(key: 'site_title', value: 'Name Of This Blog')
        # @db[:settings].insert(key: 'site_short_title', value: 'Blog')
        # @db[:settings].insert(key: 'site_owner', value: 'Your Name Here')
        @db[:settings].insert(key: 'site_title', value: 'Marty Angrily Rebukes Stupidity')
        @db[:settings].insert(key: 'site_short_title', value: 'MARS')
        @db[:settings].insert(key: 'site_owner', value: 'Martin Tithonium')
        @db[:settings].insert(key: 'items_per_page', value: '15')
        @db[:settings].insert(key: 'recent_items_count', value: '5')
        require 'securerandom'
        @db[:settings].insert(key: 'cookie_salt', value: SecureRandom.hex(32))
      end
      # unless @db[:settings][key: 'username'] && @db[:settings][key: 'password']
      #   STDERR.puts "Username and password need to be set. Until then, all users will be directed to the configuration page."
      # end
    rescue => ex
      STDERR.puts "failed to connect to db"
      @app = ErrorApp.new(ex, "Unable to connect to database. Please check the configuration.")
    end
    
  end
  
  class Setting < Sequel::Model
    unrestrict_primary_key
    
    def_dataset_method(:for) do |k|
      where(key: k.to_s).first || Setting.new(key: k.to_s)
    end
    
    def self.[](k)
      # TODO: Cache this for a time, preferably in a shared store.
      (r = dataset[key: k.to_s]) && r.value
    end
    
    def name
      key.to_s.split('_').collect(&:capitalize).join(' ')
    end
    
  end
  class Post < Sequel::Model
    def_dataset_method(:reversed) do
      order(Sequel.desc(:created_at))
    end
    def_dataset_method(:recent) do
      reversed.limit(Setting[:recent_items_count].to_i)
    end
    
    def content
      html = body
      unless html =~ /</
        html = '<p>' + html.gsub(/((\r?\n){2,})/, '</p>\1<p>') + '</p>'
      end
      unless html =~ /\A<(p|div)/
        html = html =~ /<(p|div|h\d)/ ? "<div>#{html}</div>" : "<p>#{html}</p>"
      end
      html
    end
    
    def created_year
      created_at.year
    end
    def created_month
      Date::MONTHNAMES[created_at.month]
    end
    def created_day
      created_at.day
    end
    def striped_month
      created_month.sub(/(...)(.+)/, '\1<span>\2</span>')
    end
    
    def url_title
      title.gsub(/[,\."'`~!@#\$%\^&*\(\)_\+\[\]\{\}\\\|;:\<\>\/\?-]+/, '').split(/\W+/).join('-')
    end
    
    def url
      parts = created_at.to_a[3...6].reverse
      parts << id
      parts << url_title
      "/%4.4d/%2.2d/%2.2d/%d-%s" % parts
    end
    
    def full_url
      "#{$site_root}#{url}"
    end
    
  end
end

