require 'yaml'
require 'logger'
require 'sequel/core'
require 'sequel/model'

module PunyBlog
  module Database
    
    def self.db ; @db ; end
    def self.app ; @app ; end
    
    unless File.exists?("database.yml")
      open("database.yml", "w") do |fp|
        fp.puts "---\n:adapter: mysql\n:host: db.example.com\n:database: my_blog\n:user: user\n:password: drowssap\n"
      end
      STDERR.puts "failed to find config"
      @app = ErrorApp.new("No database configuration. Please edit database.yml")
    end
    
    begin
      @db_config = YAML.load(IO.read("database.yml"))
      @db = Sequel.connect @db_config.merge(
        logger: Logger.new($stderr)
      )
      Sequel::Model.plugin :timestamps
    rescue => ex
      STDERR.puts "failed to connect to db"
      @@app = ErrorApp.new(ex, "Unable to connect to database. Please check the configuration.")
    end
    
    begin
      @db.create_table(:posts, charset: 'utf8') do
        primary_key :id
        String :title, :index => true, :null => false
        text   :content, :null => false
        Time   :created_at, :null => false
      end unless @db.tables.include?(:posts)
      # @db.create_table(:settings, charset: 'utf8') do
      #   String :key,   :index => true,  :null => false
      #   String :value, :index => false, :null => false
      # end unless @db.tables.include?(:settings)
    rescue => ex
      STDERR.puts "failed to connect to db"
      @@app = ErrorApp.new(ex, "Unable to connect to database. Please check the configuration.")
    end
    
  end
  
  # class Setting < Sequel::Model
  # end
  class Post < Sequel::Model
    RECENT_LIMIT = 15
    
    def_dataset_method(:reversed) do
      order(Sequel.desc(:created_at))
    end
    def_dataset_method(:recent) do
      reversed.limit(RECENT_LIMIT)
    end
    
    def url_title
      title.gsub(/[,\."'`~!@#\$%\^&*\(\)_\+\[\]\{\}\\\|;:\<\>\/\?-]+/, '').split(/\W+/).join('-')
    end
    
    def url
      # [
      #   id,
      #   url_title
      #   ].join('-')
      date = created_at.to_a[0...6].reverse
      date << url_title
      "/%4.4d%2.2d%2.2d/%2.2d%2.2d%2.2d/%s" % date
    end
    
  end
end

