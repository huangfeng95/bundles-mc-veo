# Motion Compensated Visual-Event Odometry - Bundles

This bundles is compatible with [Rock roby](https://github.com/rock-core/tools-roby) plan manager.
If you don't know about Rock roby you can just ignore it.

```
roby gen myrobot
```

A basic Roby application has the following directories:

**config:** configuration files. config/init.rb is the main configuration file (loaded
	by all robots). Robot-specific configuration is in config/robots/ROBOTNAME.rb.
	The main Roby configuration file is config/roby.yml. The default file
  describes all available configuration options.

**config:orogen:** contains yaml configuration files to run the programs

**config:data:** contains camera calibration files for the dataset

**data:** binary files for visuals

**scripts:** ruby executing  scripts (the main reason for this bundles)

Use `roby gen` to create new models or robot configuration files. Running the
command without further arguments shows which generators are available, and
then adding `--help` provides detailed help for a given generator, e.g. `roby
gen robot --help`

