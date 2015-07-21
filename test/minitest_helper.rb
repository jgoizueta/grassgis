$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'grassgis'

require 'minitest/autorun'

def quoted_name(name)
  SysCmd.escape(name)
end

def dummy_config
  {
    gisbase: '/usr/local/Cellar/grass-70/7.0.0/grass-7.0.0',
    gisdbase: '/grassdata',
    location: 'world',
    mapset: 'PERMANENT',
  }
end
  
