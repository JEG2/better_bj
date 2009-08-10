# encoding: UTF-8

require "test_helper"

require "better_bj/job"

class TestJob < Test::Unit::TestCase
  def test_parent_classes_are_abstract_while_child_classes_are_not
    [BetterBJ::Table, BetterBJ::Job].each do |parent|
      assert(parent.abstract_class?, "#{parent.name} class was not abstract")
    end
    [BetterBJ::ActiveJob, BetterBJ::ExecutedJob].each do |child|
      assert(!child.abstract_class?, "#{child.name} class was abstract")
    end
  end
end
