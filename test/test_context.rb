require 'minitest_helper'

class TestContext < Minitest::Test
  def test_session_commands
    cmd = nil
    GrassGis.session dummy_config do
      cmd = r.resamp.stats input: "map1", output: "map2"
    end
    assert_equal "r.resamp.stats input=#{quoted_name('map1')} output=#{quoted_name('map2')}", cmd.to_s
  end

  def test_session_locals
    value = nil
    GrassGis.session dummy_config.merge(locals: { x: 11 }) do
      value = x
    end
    assert_equal 11, value
  end

  def test_session_default_vars
    python = gnuplot = nil
    ENV['GRASS_PYTHON'] = ENV['GRASS_GNUPLOT'] = nil
    GrassGis.session dummy_config do
      python = ENV['GRASS_PYTHON']
      gnuplot = ENV['GRASS_GNUPLOT']
    end
    assert_equal 'python', python
    assert_equal 'gnuplot -persist', gnuplot
  end

  def test_session_path
    path = ENV['PATH']
    session_path = nil
    GrassGis.session dummy_config do
      session_path = ENV['PATH']
    end
    grass_dir = File.join(dummy_config[:gisbase], 'bin')
    if OS.windows?
      grass_dir = grass_dir.gsub(File::SEPARATOR, File::ALT_SEPARATOR)
    end
    session_dirs = session_path.split(File::PATH_SEPARATOR)
    assert session_dirs.include?(grass_dir)
    refute path.split(File::PATH_SEPARATOR).include?(grass_dir)
    assert_equal path, ENV['PATH']
  end

  def test_session_gisrc
    session_gisrc = session_exists_gisrc = session_gisrc_contents = nil
    GrassGis.session dummy_config do
      session_gisrc = ENV['GISRC']
      session_exists_gisrc = File.file?(session_gisrc)
      if session_exists_gisrc
        session_gisrc_contents = File.read(session_gisrc)
      end
    end
    refute session_gisrc.nil?
    # assert_nil ENV['GISRC']
    assert session_exists_gisrc
    refute session_gisrc_contents.empty?
    refute session_gisrc_contents.lines.grep(/\AMAPSET:\s*.+$/).empty?
    refute session_gisrc_contents.lines.grep(/\AGISDBASE:\s*.+$/).empty?
    refute session_gisrc_contents.lines.grep(/\ALOCATION_NAME:\s*.+$/).empty?
    refute File.exists?(session_gisrc)
  end

  def test_session_history
    history = nil
    last = nil
    history_size_at_2 = history_size_at_4 = nil
    GrassGis.session dummy_config do
      g.region res: 10
      g.region res: 20
      history_size_at_2 = self.history.size
      g.region res: 30
      g.region res: 40
      history_size_at_4 = self.history.size
      history = self.history.dup
      last = self.last.dup
    end
    assert_equal 2, history_size_at_2
    assert_equal 4, history_size_at_4
    assert_equal "g.region res=#{quoted_name('10')}", history[-4].to_s
    assert_equal "g.region res=#{quoted_name('20')}", history[-3].to_s
    assert_equal "g.region res=#{quoted_name('30')}", history[-2].to_s
    assert_equal "g.region res=#{quoted_name('40')}", history[-1].to_s
    assert_equal "g.region res=#{quoted_name('40')}", last.to_s
  end

  def test_session_raise_errors
    test_context = self
    GrassGis.session dummy_config.merge(dry: false) do
      test_context.assert_raises {
        g.invalid.command map: 'xxx'
      }
    end
  end

  def test_session_silent_errors
    test_context = self
    GrassGis.session dummy_config.merge(dry: false, errors: :silent) do
      test_context.refute error?
      g.invalid.command map: 'xxx'
      test_context.assert error?
    end
  end

  def test_session_quiet_raise_errors
    test_context = self
    GrassGis.session dummy_config.merge(dry: false, errors: :quiet) do
      test_context.refute error?
      test_context.assert_raises {
        g.invalid.command map: 'xxx'
      }
      test_context.assert error?
    end
  end

  def test_logging
    log_file = File.join(File.dirname(__FILE__), 'tmp_log.txt')
    GrassGis.session dummy_config.merge(log: log_file) do
      g.invalid.command map: 'xxx'
    end
    assert File.exists?(log_file)
    assert_match /g\.invalid\.command map=/, File.read(log_file)
    File.unlink log_file if File.exists?(log_file)
  end

  def test_logging_errors
    log_file = File.join(File.dirname(__FILE__), 'tmp_log.txt')
    GrassGis.session dummy_config.merge(log: log_file, dry: false, errors: :silent) do
      g.invalid.command map: 'xxx'
    end
    assert File.exists?(log_file)
    assert_match /g\.invalid\.command map=/, File.read(log_file)
    assert_match /error/i, File.read(log_file)
    File.unlink log_file if File.exists?(log_file)
  end

  def test_logging_history
    log_file = File.join(File.dirname(__FILE__), 'tmp_log.txt')
    GrassGis.session dummy_config.merge(history: log_file) do
      g.invalid.command map: 'xxx'
    end
    assert File.exists?(log_file)
    assert_match /g\.invalid\.command map=/, File.read(log_file)
    File.unlink log_file if File.exists?(log_file)
  end

  def test_session_with_parameter
    outer_self = object_id
    inner_self = nil
    passed_parameter = nil
    GrassGis.session dummy_config do |grass|
      inner_self = object_id
      passed_parameter = grass
    end
    assert_equal outer_self, inner_self
    assert passed_parameter.is_a?(GrassGis::Context)
  end

  def test_version_numbers
    version = nil
    GrassGis.session dummy_config do
      version = grass_version
    end
    assert_equal '1.0.0', version.to_s
    GrassGis.session dummy_config.merge(version: '7.10.0') do
      version = grass_version
    end
    assert_equal '7.10.0', version.to_s
    assert version > GrassGis.version('7.9.10')
  end
end
