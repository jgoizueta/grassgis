$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'grassgis'

require 'minitest/autorun'

def quoted_name(name)
  SysCmd.escape(name)
end
