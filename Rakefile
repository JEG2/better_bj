#!/usr/bin/env rake

require "rake/testtask"

task :default => [:test]

Rake::TestTask.new do |test|
  test.libs       << "test"
  test.test_files =  Dir["test/test_*.rb"] - %w[test/test_helper.rb]
  test.verbose    =  true
end
