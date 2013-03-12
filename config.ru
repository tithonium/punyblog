#!/usr/bin/env ruby

begin
  # use `bundle install --standalone' to get this...
  require_relative 'bundle/bundler/setup'
rescue LoadError
  # fall back to regular bundler if the person hasn't bundled standalone
  require 'bundler'
  Bundler.setup
end

$LOAD_PATH.unshift File.expand_path('../lib', __FILE__)

require 'puny_blog/apps'
require 'puny_blog/database'

@theApp = PunyBlog::Database.app ||
          PunyBlog::BlogApp.new(PunyBlog::Database.db)

run @theApp
