require "celluloid/rspec"
require "celluloid/pool"

Dir[ *Specs::INCLUDE_PATHS ].map { |f| require f }
