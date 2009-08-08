# encoding: UTF-8

require "better_bj/table"

module BetterBJ
  class Job < Table
    self.abstract_class = true
  end
  
  class ActiveJob < Job
    
  end
  
  class ArchivedJob < Job
    
  end
end
