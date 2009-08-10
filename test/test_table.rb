# encoding: UTF-8

require "test_helper"

require "better_bj/table"
require "better_bj/job"  # ensure some tables are loaded

class TestTable < Test::Unit::TestCase
  #################
  ### Interface ###
  #################
  
  def test_table_method_interface
    assert_equal(BetterBJ::Table, BetterBJ.table)
  end
  
  def test_table_list
    # fetch full list
    assert_instance_of(Array, BetterBJ::Table.list)

    # list contents and method access
    [BetterBJ::Job, BetterBJ::ActiveJob, BetterBJ::ExecutedJob].each do |table|
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
  
  def test_each_and_reverse_each_can_optionally_skip_abstract_and_sti_classes
    # default:  include abstract and STI classes
    assert( BetterBJ.table.any? { |t| t.abstract_class? },
            "An abstract class was not returned by each by default" )
    assert( BetterBJ.table.any? { |t| t.name =~ /\bActive\w+Job\z/ },
            "An STI class was not returned by each by default" )
    saw_abstract = false
    saw_sti      = false
    BetterBJ.table.reverse_each do |table|
      saw_abstract = true if table.abstract_class?
      saw_sti      = true if table.name =~ /\bActive\w+Job\z/
    end
    assert( saw_abstract,
            "An abstract class was not returned by reverse_each by default" )
    
    # optional:  request to skip them
    BetterBJ.table.each(:skip_abstracts_and_stis) do |table|
      assert( !table.abstract_class?,
              "An abstract was included by each with skipping" )
      assert_no_match(/\bActive\w+Job\z/, table.name)
    end
    BetterBJ.table.reverse_each(:skip_abstracts_and_stis) do |table|
      assert( !table.abstract_class?,
              "An abstract was included by reverse_each with skipping" )
      assert_no_match(/\bActive\w+Job\z/, table.name)
    end
  end
  
  ##############
  ### Schema ###
  ##############
  
  def test_field_adds_to_fields_added_by_this_class
    table = new_table
    assert_equal(0, table.fields_added_by_this_class.size)
    field = [:whatever, :string]
    table.field(*field)
    assert_equal(1,     table.fields_added_by_this_class.size)
    assert_equal(field, table.fields_added_by_this_class.first)
  end
  
  def test_field_fails_on_bad_column_type
    table = new_table
    assert_raise(RuntimeError) do
      table.field :whatever, :bad_type
    end
    assert_nothing_raised(RuntimeError) do
      table.field :ok, :string
    end
  end
  
  def test_fields_lists_all_fields_added_in_class_hierarchy_order
    parent = new_table do
      field :first, :integer
    end
    child = new_table(parent) do
      field :second, :integer
    end
    other = new_table do
      field :not_inherited, :string
    end
    assert_equal(1,              parent.fields.size)
    assert_equal(:first,         parent.fields.first.first)
    assert_equal(2,              child.fields.size)
    assert_equal(:first,         child.fields.first.first)
    assert_equal(:second,        child.fields.last.first)
    assert_equal(1,              other.fields.size)
    assert_equal(:not_inherited, other.fields.first.first)
  end
  
  def test_table_extras_can_be_set_for_each_class
    table = new_table
    assert_equal(0, table.table_extras.size)
    extra = "extra"
    table.table_extras(extra)
    assert_equal(1,     table.table_extras.size)
    assert_equal(extra, table.table_extras.first)
  end
  
  def test_the_table_name_is_added_for_add_index_calls_if_missing
    table = new_table do
      set_table_name "test_jobs"
    end
    table.table_extras(<<-END_RUBY)
    skip_me()
    add_index :column
    add_index(:column)
    add_index( :column)
    add_index ( :column)
    add_index :test_jobs, :column
    add_index(:test_jobs, :column)
    add_index( :test_jobs, :column)
    add_index ( :test_jobs, :column)
    add_index 'test_jobs', :column
    add_index('test_jobs', :column)
    add_index( 'test_jobs', :column)
    add_index ( 'test_jobs', :column)
    add_index "test_jobs", :column
    add_index("test_jobs", :column)
    add_index( "test_jobs", :column)
    add_index ( "test_jobs", :column)
    END_RUBY
    assert_equal(16, table.table_extras.join.scan("test_jobs").size)
  end
  
  def test_table_extras_lists_all_extras_in_class_hierarchy_order
    parent = new_table do
      table_extras "first"
    end
    child = new_table(parent) do
      table_extras "second"
    end
    other = new_table do
      table_extras "not_inherited"
    end
    assert_equal(1,               parent.table_extras.size)
    assert_equal("first",         parent.table_extras.first)
    assert_equal(2,               child.table_extras.size)
    assert_equal("first",         child.table_extras.first)
    assert_equal("second",        child.table_extras.last)
    assert_equal(1,               other.table_extras.size)
    assert_equal("not_inherited", other.table_extras.first)
  end
  
  def test_migration_produces_typical_rails_code
    table_migration = BetterBJ::ActiveJob.migration
    assert_match( / ^\s*create_table\s+
                    :#{Regexp.escape(BetterBJ::ActiveJob.table_name)}
                    /x,                 table_migration[0] )
    assert_match(/^\s*t\.text :code\b/, table_migration.join("\n"))
    assert_match(/^\s*t.timestamps/,    table_migration[-2] )
    
    full_migration = BetterBJ::Table.migration
    assert_match( / ^\s*class\s+\S+\s+<\s+
                    ActiveRecord::Migration\b /x, full_migration[0] )
    assert_match(/^\s+def\s+self\.up\b/,          full_migration.join("\n"))
    assert_match(/^\s+def\s+self\.down\b/,        full_migration.join("\n"))
    table_migration.each do |line|
      assert( full_migration.join("\n").include?(line),
              "Table migration line not found in the full migration" )
    end
  end
  
  def test_migration_is_valid
    prepare_test_db  # ensure we can migrate the database with valid code
    BetterBJ.table.each(:skip_abstracts_and_stis) do |table|
      assert( table.table_exists?,
              "Table #{table} was not created by the migrations" )
    end
  ensure
    cleanup_test_db
  end
  
  #######
  private
  #######
  
  def new_table(parent = BetterBJ::Table, &definition)
    Class.new(parent, &definition)
  end
end
