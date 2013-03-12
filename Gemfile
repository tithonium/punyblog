source 'https://rubygems.org'

gem 'rack'

gem 'mustache'

# gem 'yajl-ruby'
# gem 'multi_json'
# gem 'hashie'

# gem 'whenever'
# gem 'rack-contrib'
# gem 'e20_ops_middleware'
gem 'mysql'
gem 'sequel'

group :production, :staging do
  gem 'unicorn'
end

group :development, :test do
  gem 'shotgun'
  
  gem 'capistrano'
end
