# encoding: UTF-8

require "test_helper"

require "rubygems"
require "active_record"

require "better_bj/table"
require "better_bj/job"  # ensure some tables are loaded

class TestTable < Test::Unit::TestCase
  def test_table_method_interface
    assert_equal(BetterBJ::Table, BetterBJ.table)
  end
  
  def test_table_list
    # fetch full list
    assert_instance_of(Array, BetterBJ::Table.list)

    # list contents and method access
    [BetterBJ::Job, BetterBJ::ActiveJob, BetterBJ::ArchivedJob].each do |table|
      assert( BetterBJ.table.list.include?(table),
              "Table #{table} is not listed" )
      assert_equal(table, BetterBJ.table.send(table.name[/[^:]+\z/].underscore))
    end
    
    # each() and reverse_each()
    list = BetterBJ.table.list.dup
    BetterBJ.table.each do |eached|
      assert_equal(list.shift, eached)
    end
    reversed_list = BetterBJ.table.list.reverse
    BetterBJ.table.reverse_each do |eached|
      assert_equal(reversed_list.shift, eached)
    end
    # other Enumerable methods
    assert_not_nil(BetterBJ.table.detect { |t| not t.abstract_class? })
  end
  
  def test_parent_classes_are_abstract_while_child_classes_are_not
    [BetterBJ::Table, BetterBJ::Job].each do |parent|
      assert(parent.abstract_class?, "#{parent.name} class was not abstract")
    end
    [BetterBJ::ActiveJob, BetterBJ::ArchivedJob].each do |child|
      assert(!child.abstract_class?, "#{child.name} class was abstract")
    end
  end
end
