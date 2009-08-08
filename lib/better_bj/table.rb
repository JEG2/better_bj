# encoding: UTF-8

module BetterBJ
  class Table < ActiveRecord::Base
    module Listed
      def inherited(table)
        super
      ensure
        (Table.list << table).uniq!
        Table.instance_eval <<-END_RUBY
        def #{table.name[/[^:]+\z/].underscore}
          #{table.name}
        end
        END_RUBY
        table.extend(Listed)
      end
    end
    extend Listed
    
    self.abstract_class = true
    
    def self.list
      @list ||= [ ]
    end
    
    def self.each(&iterator)
      list.each(&iterator)
    end
    extend Enumerable
    
    def self.reverse_each(&iterator)
      list.reverse_each(&iterator)
    end
  end
  
  def table
    Table
  end
  module_function :table
end
