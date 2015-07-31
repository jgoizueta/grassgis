require 'minitest_helper'

class TestCreate< Minitest::Test
  def setup
    if OS.windows?
      skip
      return
    end
    mock_grass = File.expand_path('grass', File.dirname(__FILE__))
    @gisdbase = File.join(mock_grass, 'gisdbase')
  end

  def teardown
    Dir[File.join(@gisdbase, '*')].each do |fn|
      next if File.basename(fn) == 'a_location'
      FileUtils.rm_rf fn
    end
    Dir[File.join(@gisdbase, 'a_location', '*')].each do |fn|
      next if %w(PERMANENT a_mapset).include?(File.basename(fn))
      FileUtils.rm_rf fn
    end
  end

  def test_create_location
    config =  dummy_config.merge(
      location: 'other_location',
      mapset: 'other_mapset',
      dry: false,
      create: {
        epsg: 25830,
        limits: [400000, 4600000, 600000, 4700000],
        res: 10000
      },
      log: 'test.log'
    )
    wind = nil
    GrassGis.session config do
      g.region '-p'
      wind = output
    end
    assert File.directory?(File.join(@gisdbase, 'other_location'))
    assert File.file?(File.join(@gisdbase, 'other_location', 'PERMANENT', 'DEFAULT_WIND'))
    assert File.file?(File.join(@gisdbase, 'other_location', 'PERMANENT', 'WIND'))
    assert File.file?(File.join(@gisdbase, 'other_location', 'other_mapset', 'WIND'))
    assert_match /south:\s+4600000\b/, wind
    assert_match /north:\s+4700000\b/, wind
    assert_match /east:\s+600000\b/, wind
    assert_match /west:\s+400000\b/, wind
    assert_match /e-w resol:\s+10000\b/, wind
    assert_match /n-s resol:\s+10000\b/, wind
  end

  def test_create_mapset
    config =  dummy_config.merge(
      location: 'a_location',
      mapset: 'other_mapset',
      dry: false,
      create: {
        epsg: 25830,
        limits: [400000, 4600000, 600000, 4700000],
        res: 10000
      }
    )
    wind = nil
    GrassGis.session config do
      g.region '-p'
      wind = output
    end
    assert File.file?(File.join(@gisdbase, 'a_location', 'other_mapset', 'WIND'))
    assert_match /south:\s+\-90\b/, wind
    assert_match /north:\s+90\b/, wind
    assert_match /east:\s+180\b/, wind
    assert_match /west:\s+\-180\b/, wind
    assert_match /e-w resol:\s+1\b/, wind
    assert_match /n-s resol:\s+1\b/, wind
  end
end
