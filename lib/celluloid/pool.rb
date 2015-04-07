require 'celluloid'
require 'celluloid/supervision_group'
require 'celluloid/pool_manager'

module Celluloid
  class << self
    # Create a new pool of workers. Accepts the following options:
    #
    # * size: how many workers to create. Default is worker per CPU core
    # * args: array of arguments to pass when creating a worker
    #
    def pool(klass=self,options={})
      PoolManager.new(klass, options)
    end

    # Same as pool, but links to the pool manager
    def pool_link(options = {})
      PoolManager.new_link(self, options)
    end
  end
end