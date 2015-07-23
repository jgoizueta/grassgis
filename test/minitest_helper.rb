$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'grassgis'

require 'minitest/autorun'

def quoted_name(name)
  SysCmd.escape(name)
end

def dummy_config
  {
    gisbase: '/nonexistent/path',
    gisdbase: '/grassdata',
    location: 'world',
    mapset: 'PERMANENT',
  }.merge(
    # Test options
    dry: true,  # don't execute commands
    echo: false # don't output to the console
  )
end
