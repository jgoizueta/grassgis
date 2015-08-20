# GrassGis

[![Gem Version](https://badge.fury.io/rb/grassgis.svg)](http://badge.fury.io/rb/grassgis)
[![Build Status](https://travis-ci.org/jgoizueta/grassgis.svg)](https://travis-ci.org/jgoizueta/grassgis)

Support for scripting GRASS with Ruby.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Installation](#installation)
- [Usage](#usage)
  - [Configuration](#configuration)
  - [Running a GRASS Session](#running-a-grass-session)
  - [Creating new locations and mapsets](#creating-new-locations-and-mapsets)
  - [History](#history)
  - [Options](#options)
    - [Echo](#echo)
    - [Errors](#errors)
    - [Logging](#logging)
  - [Technicalities](#technicalities)
    - [Session scopes](#session-scopes)
    - [Invalid commands](#invalid-commands)
- [Helper methods](#helper-methods)
  - [Examples](#examples)
    - [1. Map existence](#1-map-existence)
    - [2. Information as Hashes](#2-information-as-hashes)
    - [3. Average angle](#3-average-angle)
- [Roadmap](#roadmap)
  - [GRASS cooking DSL](#grass-cooking-dsl)
- [Contributing](#contributing)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

Add this line to your application's Gemfile:

    gem 'grassgis'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install grassgis

## Usage

This library can prepare environments to execute GRASS commands
from Ruby scripts.

First we require the library:

```ruby
require 'grassgis'
```

### Configuration

A GRASS session operates on a given location and mapset.

Before starting a GRASS session we need some configuration
parameters to specify the location of the GRASS Installation
to be used and the location/mapset. We do this by using
a Ruby Hash containing configuration parameters:

```ruby
configuration = {
  gisbase: '/usr/local/grass-7.0.0',
  gisdbase: File.join(ENV['HOME'], 'grassdata'),
  location: 'nc_spm',
  mapset: 'user1'
}
```

So, you first need to know where is GRASS installed on your system
to define the `:gisbase` option to point to the base directory of the GRASS
installation.

For *Ubuntu* it will typically be `/usr/lib/grass70` for version 7 of GRASS.

In *Windows*, if installed with
[OSGeo4W](http://trac.osgeo.org/osgeo4w/) it is typically of
the form `C:\OGeo4W\app\grass\grass-7.0.0` (the last directory will vary
depending on the GRASS version).

Under *Mac OS X*, if using [Homebrew](http://brew.sh/)
(with the [osgeo/osgeo4mac](https://github.com/OSGeo/homebrew-osgeo4mac) tap)
it should bd something like `/usr/local/Cellar/grass-70/7.0.0/grass-7.0.0`.

You can find the `:gisbase` directory by executing the
`grass` command of your system (which may be `grass70`, `grass64`, etc.)
with the `--config path` option:

    grass --config path

You must also specify the `GISDBASE`, `LOCATION` and `MAPSET`, to work with,
just like when starting GRASS, through the `:gisdbase`, `:location` and
`:mapset` configuration options.
You can omit `:gisdbase` which will default to a directory named `grassdata` in the
user's home directory and `:mapset` which defaults to `PERMANENT`.


### Running a GRASS Session

With the proper configuration in place, we can use it to
create a GRASS Session and execute GRASS command from it:

```ruby
GrassGis.session configuration do
  g.list 'vect'
  puts output # will print list of vector maps
end
```

Inside a `GrassGis` session we can execute GRASS commands
just by using the command name as a Ruby method.

Command flags and options must be passed first as regular method arguments,
then named parameters must be passed as a Ruby Hash:

```ruby
g.region '-p', rast: 'elevation'
d.rast 'elevation'
d.vect 'streams', col: 'blue'
```

If you try to execute an invalid module name an `ENOENT`
error will be raised:

```ruby
g.this.module.does.not.exist '???'
```

If the command to be executed has no arguments you need
to invoke `.run` on it to execute it:

```ruby
d.erase.run
g.list.run
```

### Creating new locations and mapsets

To create a new location and/or mapset, open a session to it
and use a `:create` parameter like this:

```ruby
options = configuration.merge(
  location: 'new_location',
  mapset: 'new_mapset',
  create: {
    epsg: 4326               # coordinate system for the new location
    limits: [-5, 30, 5, 50], # optional E, S, W, N limits
    res: 2                   # optional resolution
  }
)
GrassGis.session options do
  g.region '-p'
  puts output
end
```

Use `nil` or `PERMANENT` for the mapset to avoid creating a new mapset.

Existing locations or mapsets are not changed.

### History

The return value of a GRASS command invocation inside a session is
a `SysCmd::Command`
(see the [sys_cmd gem](https://github.com/jgoizueta/sys_cmd)).

```ruby
GrassGis.session configuration do+
  cmd = g.region '-p'
  puts cmd.output # command output is kept in the Command object
  puts cmd.status_value # 0 for success
end
```

You don't need to assign commands to variables as in the example
to access them, because they're all kept in an array accesible
through the `history` method of the session:

```ruby
GrassGis.session configuration do+
  r.info 'slope'
  g.region '-p'
  puts history.size       # 2
  puts history[-1].output # output of g.region
  puts history[-2].output # output of r.info
end
```

The last executed command (`history[-1]`) is also accessible through
the `last` method and its output through `output`:

```ruby
GrassGis.session configuration do+
  r.info 'slope'
  g.region '-p'
  puts output # output of g.region (same as last.output)
  puts last.status_value # result status of g.region
end
```

### Options

By default the commands executed in a session are echoed to standard output
(just the command, not its output) and error return status causes
an exception to be raised.

This behaviour can be changed with some options:

#### Echo

Pass `false` as the `:echo` option it you don't want to output
command names and `:output` if you want to output both
the command name and its output.

```ruby
GrassGis.session configuration.merge(echo: false) do
  # Command names not echoed now ...
end

GrassGis.session configuration.merge(echo: :output) do
  # Command names and its output echoed ...
end
```

#### Errors

To avoid raising exceptions when commands return an error status you can pass
`:quiet` to the `:errors` option. In that case the `error?` method of the
session can be used to check if the previous messatge returned an error status;
`error_info` to get its error message and the status of the command
of the command can be obtained through the `last` command method.

```ruby
GrassGis.session configuration.merge(errors: :quiet) do
  r.surf.rst 'randpts', elev: 'rstdef', zcol: 'value'
  if error?
    puts "Last command didn't go well..."
    puts "It returned the code: #{last.status_value}"
    puts "Here's what it said about the problem:"
    puts error_info
  end
end
```

With the `:quiet` option errors during command execution are not raised,
but if a problem prevents the command from being executed (e.g. the
module does not exist) an exception is still generated. This exception
can be avoided too, with the `:silent` option, intended for tests and
debugging.

Passing the `:console` value to the `:errors` option is like `:quiet`,
with the additional effect of relaying the command standard error output
to the error output of the script.

#### Logging

With the `:log` option you can specify the name of a file
where to record the commands executed and its output.

### Technicalities

#### Session scopes

In a session block, the Ruby `self` object is altered to
refer to a `GrassGis::Context` object. That means that in addition
to the enclosing `self`, any instance variables of the enclosing
scope are not directly available. This may cause some surprises
but is easy to overcome.

```ruby
@value = 10
GrassGis.session configuration do
  puts @value # nil!
end
```

A possible workaround is to assign instance variables that we need
in the session to local variables:

```ruby
@value = 10
value = @value
GrassGis.session configuration do
  puts value # 10
end
```

To avoid defining these variables you can pass a `:locals` Hash
in the configuration to define values that you need to access
in the session (but you won't be able to assign to them, because
they're not local variables!)

```ruby
@value = 10

GrassGis.session configuration.merge(locals: { value: @value }) do
  puts value # 10
  value = 11 # don't do this: you're creating a local in the session
end
```

A different approach is prevent the session block from using a special
`self` by defining a parameter to the block. This parameter will have
the value of a `GrassGis::Context` which you'll need to explicitly use
to execute any commands:

```ruby
@value = 10
GrassGis.session configuration do |grass|
  puts @value # 10
  grass.g.region res: 10 # now you need to use the object to issue commans
end
```

The GRASS command `g.mapset` should not be used to change
the current mapset, use the `change_mapset` method in a GrassGis
session instead:

```ruby
GrassGis.session configuration do
  # Get the name of the current mapset
  g.mapsets '-p'
  mapset = output.lines.last.split.first.inspect
  # Copy 'some_map' raster map to PERMANENT
  change_mapset 'PERMANENT'
  g.copy rast: "some_map@#{original_mapset},some_map"
  # Get back to our mapset
  change_mapset mapset
end
```

#### Invalid commands

Currently the generation of GRASS commands inside a session is
implemented in a versy simple way which allows to generate any command
name even if it is invalid or does not exist. This has the advantage
of supporting any version of GRASS, but doesn't allow for early
detection of invalid commands (e.g. due to typos) or invalid command
parameters.

```ruby
GrassGis.session configuration do |grass|
  g.regoin res: 10     # Oops (runtime error)
  g.anything.goes.run  # another runtime error
end
```

If the command generated does not exist a runtime `ENOENT` exception will
occur.

If the command exists, then if parameters are not valid, the command
will execute but will return an error status. This will be handled
as explaned above.

## Helper methods

When writing a non-trivial program you'll probably
find you want to define methods to avoid unnecessary repetition.

Let's see how you can call methdos from your session and be
able to execute GRASS commands from the method in the context of the session.

Inside a session, `self` refers to an object of class
`GrassGis::Context` which represents the current GRASS session.

You can invoke grass commands directly on this object, so, if you pass
this object around you can use it to execute GRASS commands:

```ruby
def helper_method(grass)
  # ...
end

GrassGis.session configuration do
  helper_method self
end
```

In the helper method you can use the grass object like this;

```ruby
def helper_method(grass)
  # change the current region resolution
  grass.g.region res: 10
end
```

To avoid having to prepend each command with `grapss.` you can
use the `session` method like this:

```ruby
def helper_method(grass)
  grass.session do
    g.region res: 10
    g.region '-p'
    puts output
  end
end
```

### Examples


#### 1. Map existence

Helper methods to check for the existence of maps.

Often we may want to know if a map exists. Next methods can be used to
check for it.

```ruby
def map_exists?(grass, type, map)
  grass.g.list type
  maps = grass.output.split
  maps.include?(map)
end

def raster_exists?(grass, map)
  map_exists? grass, 'rast', map
end

def vector_exists?(grass, map)
  map_exists? grass, 'vect', map
end
```

We can use these methods like this:

```ruby
GrassGis.session configuration do
  unless raster_exists?(self, 'product')
    r.mapcalc "product = factor1*factor2"
  end
end
```

#### 2. Information as Hashes

Following methods show how to obtain information about a raster map
and the current region as a Hash:

```ruby
def raster_info(grass, map)
  grass.r.info '-g', map
  shell_to_hash grass
end

def region_info(grass)
  grass.g.region '-m'
  shell_to_hash grass
end

def shell_to_hash(grass)
  Hash[grass.output.lines.map{|l| l.strip.split('=')}]
end

# Now, for example, we can easily obtain the resolution of a raster:

def raster_res(grass, map)
  info = raster_info(grass, map)
  info.values_at('ewres', 'nsres').map(&:to_i)
end

def region_res(grass)
  info = region_info(grass)
  info.values_at('ewres', 'nsres').map(&:to_i)
end
```

#### 3. Average angle

Let's assume we have a raster map `aspect` which is
a direction angle (i.e. a cyclic value from 0 to 360).

Now imagine that we need to compute a coarser raster grid with
average values per cell. We can't just resample the angle
(we want the average of 359 and 1 be 0, not 180);
we would need an unitary vector or complex number to take averages.

The next method will perform the average correctly using
auxiliary raster maps for two cartesian components (that represent
the angle as a vector).

```ruby
def resample_average_angle(grass, options = {})
  input_raster = options[:input]
  raise "Raster #{input_raster} not found" unless raster_exists?(grass, input_raster)
  input_res = raster_res(grass, input_raster)

  if options[:output_res]
    output_res = options[:output_res]
    unless output_res.is_a?(Array)
      output_res = [output_res, output_res]
    end
  else
    output_res = region_res(grass)
  end

  output_raster = options[:output]

  grass.session do
    unless raster_exists?(self, "#{input_raster}_sin")
      g.region ewres: input_res[0], nsres: input_res[1]
      r.mapcalc "#{input_raster}_sin = sin(#{input_raster})"
    end
    unless raster_exists?(self, "#{input_raster}_cos")
      g.region ewres: input_res[0], nsres: input_res[1]
      r.mapcalc "#{input_raster}_cos = cos(#{input_raster})"
    end
    g.region ewres: output_res[0], nsres: output_res[1]
    r.resamp.stats input: "#{input_raster}_cos", output: "#{output_raster}_cos"
    r.resamp.stats input: "#{input_raster}_sin", output: "#{output_raster}_sin"
    r.mapcalc "#{output_raster} = atan(#{output_raster}_cos,#{output_raster}_sin)"
    r.colors map: ouput_raster, raster: input_raster
    g.remove '-f', type: 'raster', name: ["#{output_raster}_cos", "#{output_raster}_sin"]
    g.remove -f type=raster name=aspect_sin@landscape,aspect_cos@landscape
  end
end
```

Now, to resample a (cyclic angular) map `aspect_hires` to a lower resolution 10:

```ruby
GrassGis.session configuration do
  resamp_average self,
    input: 'aspect_hires',
    output: 'aspect_lowres', output_res: 10
  end
end
```

## Roadmap

* Change Module to define explicitly available GRASS commands instead of
  accepting anything with `method_missing`. Declare commands with permitted
  arguments and options, etc.
* Add some session helpers:
  - Method to clean GRASS temporaries ($GISBASE/etc/clean_temp), or do
    it automatically when disposing the session.
  - Methods to check if maps exist
  - Methods that return information as objects (arrays, hashes), e.g.
    values returned by r.what, the current region, etc.
  - Methods that execute operations in a GRASS-version independent
    manner (higher level, version independent interface to modules).

### GRASS cooking DSL

Create a DSL to define GRASS processing recipes.

It should handle errors gracefully during recipe execution,
take care of logging, parsing command output, temporary files, etc.

A recipe could have requirements such as which other recipes it depends
upon (so must be executed first), which map layers must exist, etc.

It could also define what map layers or other files are generated by the
recipe.

Example of intended recipe syntax:

```ruby
recipe :resamp_average do |options = {}|
  # ...
end

recipe :generate_working_dem do |...|
  define :working_dem, 'dem'
  define :working_slope, 'slope'
  define :working_aspect, 'aspect'
  g.region res: working_res
  apply :resamp_average, input: base_dem, output: working_dem, input_res: base_dem_res, output_res: working_res
  apply :resamp_average, input: base_slope, output: working_slope, input_res: base_dem_res, output_res: working_res
  apply :resamp_average, input: base_aspect, output: working_aspect, input_res: base_dem_res, output_res: working_res, direction: true
  describe working_slope, "Pendiente en grados a #{working_res} #{region_units}"
  # ...
end
```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/grassgis/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
