$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'grassgis'

require 'minitest/autorun'

def quoted_name(name)
  SysCmd.escape(name)
end

def dummy_config
  mock_grass = File.expand_path('grass', File.dirname(__FILE__))
  {
    gisbase:  File.join(mock_grass, 'gisbase'),
    gisdbase: File.join(mock_grass, 'gisdbase'),
    location: 'a_location',
    mapset: 'a_mapset',
  }.merge(
    # Test options
    dry: true,  # don't execute commands
    echo: false # don't output to the console
  )
end
