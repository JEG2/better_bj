# encoding: UTF-8

require "test/unit"

require "rubygems"
require "active_record"

module TestHelper
  DB_PATH = File.join(File.dirname(__FILE__), "test_db.sqlite")
  
  private
  
  #################
  ### Processes ###
  #################
  
  def pid_running?(pid)
    Process.kill(0, pid)
    true
  rescue Exception
    false
  end
  
  def assert_pid_running(pid)
    assert(pid_running?(pid), "PID #{pid} could not be found")
  end
  
  def assert_pid_not_running(pid)
    assert(!pid_running?(pid), "PID #{pid} was found")
  end
  
  ################
  ### Database ###
  ################
  
  def prepare_test_db
    ActiveRecord::Base.establish_connection(
      :adapter  => "sqlite3",
      :database => DB_PATH
    )
    ActiveRecord::Base.connection  # creates the database
    migration       = BetterBJ::Table.migration.join("\n")
    migration_class = migration[/\Aclass\s+(\S+)/, 1]
    eval( migration +
          "\n#{migration_class}.verbose = false\n#{migration_class}.up",
          TOPLEVEL_BINDING )
  end
  
  def cleanup_test_db
    ActiveRecord::Base.connection.disconnect!  # drop connection, if it exists
    File.unlink(DB_PATH) if File.exist? DB_PATH
  end
  
  ###################
  ### Validations ###
  ###################
  
  def assert_invalid_field(model, field, bad_value, other_fields = Hash.new)
    invalid = model.new(other_fields.merge(field => bad_value))
    assert(!invalid.valid?, "#{model} was valid with a bad ##{field}")
    assert( invalid.errors.invalid?(field),
            "#{model}##{field} was #{bad_value.inspect} but valid" )
  end
  
  def assert_valid_field(model, field, good_value, other_fields = Hash.new)
    valid = model.new(other_fields.merge(field => good_value))
    valid.valid?  # populate #errors
    assert( !valid.errors.invalid?(field),
            "#{model}##{field} was #{good_value.inspect} but invalid" )
  end

  def assert_required_field(model, field, good_value, other_fields = Hash.new)
    assert_invalid_field( model, field, nil,        other_fields )
    assert_valid_field(   model, field, good_value, other_fields )
  end
end

Test::Unit::TestCase.send(:include, TestHelper)
