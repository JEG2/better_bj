# encoding: UTF-8

module BetterBJ
  class Table < ActiveRecord::Base
    module Listed
      def inherited(table)
        super
      ensure
        if table.name and not table.name.empty?
          (Table.list << table).uniq!
          Table.instance_eval <<-END_RUBY
          def #{table.name[/[^:]+\z/].underscore}
            #{table.name}
          end
          END_RUBY
        end
        table.extend(Listed)
      end
    end
    extend Listed
    
    self.abstract_class = true
    
    def self.list
      @list ||= [ ]
    end
    
    def self.each(skip_abstracts = false)
      list.each do |table|
        next if skip_abstracts and table.abstract_class?
        yield table
      end
    end
    extend Enumerable
    
    def self.reverse_each(skip_abstracts = false)
      list.reverse_each do |table|
        next if skip_abstracts and table.abstract_class?
        yield table
      end
    end
    
    def self.each_parent_class
      hierarchy = self
      while hierarchy = hierarchy.superclass
        yield hierarchy
      end
    end
    private_class_method :each_parent_class
    
    def self.fields_added_by_this_class
      @fields_added_by_this_class ||= [ ]
    end
    
    def self.field(name, type, options = { })
      fail "Illegal field type" unless %w[ string   text      binary
                                           integer  float     decimal
                                           datetime timestamp time    date
                                           boolean ].include? type.to_s
      field                      =  [name, type]
      field                      << options unless options.empty?
      fields_added_by_this_class << field
    end
    
    def self.fields
      fields = fields_added_by_this_class
      each_parent_class do |hierarchy|
        fields.unshift(*hierarchy.fields_added_by_this_class) \
          if hierarchy.respond_to? :fields_added_by_this_class
      end
      fields
    end
    
    def self.table_extras(extras = nil)
      # ensure it is initialized
      @table_extras ||= nil
      # writer
      @table_extras =   extras.gsub(/ ^( \s*add_index
                                         (?>\s*\(?\s*) )
                                       (?![:"']#{Regexp.escape(table_name)})
                                      /x, "\\1:#{table_name}, ") \
                        unless extras.nil?
      # reader
      table_extras  =   Array(@table_extras)
      each_parent_class do |hierarchy|
        next unless hierarchy.instance_variable_defined? :@table_extras
        if extras = hierarchy.instance_variable_get(:@table_extras)
          table_extras.unshift(extras)
        end
      end
      table_extras
    end
    
    def self.migration
      if self == Table
        migration = ["class CreateBetterBJTables < ActiveRecord::Migration",
                     "  def self.up"]
        each(:skip_abstracts) do |table|
          migration.push(*table.migration.map { |line| "    #{line}" })
        end
        migration.push( "  end",
                        "  def self.down" )
        reverse_each(:skip_abstracts) do |table|
          migration << "    drop_table #{table.table_name}"
        end
        migration.push( "  end",
                        "end" )
      else
        migration = ["create_table :#{table_name} do |t|"]
        fields.each do |field|
          migration     << "  t.#{field[1]} :#{field[0]}"
          migration[-1] << ", #{field[3].inspect[1..-2]}" unless field[3].nil?
        end
        migration << "  t.timestamps"
        migration << "end"
        table_extras.each do |extra|
          migration << extra
        end
      end
      migration
    end
  end
  
  def table
    Table
  end
  module_function :table
end
