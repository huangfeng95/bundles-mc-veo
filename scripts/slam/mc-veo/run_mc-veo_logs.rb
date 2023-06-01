#!/usr/bin/env ruby

require 'orocos'
require 'orocos/log'
require 'rock/bundle'
require 'vizkit'
require 'readline'
require 'utilrb'
require 'optparse'
include Orocos

options = {}
options[:dataset] = nil
options[:log_type] = nil

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    run_mc_veo_davis_logs [options] <data_log_directory>
    EOD

    opt.on '--dataset=simulation_3planes/simulation_3walls/boxes_6dof/...', String, 'dataset for replaying logs' do |dataset|
        options[:dataset] = dataset
    end

    opt.on '--log_type=davis/beamsplitter/...', String, 'dataset log type' do |log_type|
        options[:log_type] = log_type
    end

    opt.on '--help', 'this help message' do
        puts opt
       exit 0
    end
end

args = op.parse(ARGV)
logfiles_path = args.shift

if !logfiles_path
    puts "missing path to log files"
    puts options
    exit 1
end

Orocos::CORBA::max_message_size = 100000000000
Bundles.initialize

Bundles.run 'mc_veo::Task' => 'mc_veo', :gdb => false, :output => '%m-%p.txt', :valgrind => false do

    # get the task
    STDERR.print "setting up mc-veo..."
    mc_veo = Bundles.name_service.get 'mc_veo'
    Bundles.conf.apply(mc_veo, [options[:dataset]], :override => true )
    STDERR.puts "done"

    # logs files
    log_replay = Orocos::Log::Replay.open( logfiles_path )

    # Log port connections
    if options[:log_type].casecmp("davis").zero?
        log_replay.davis.events.connect_to(mc_veo.events, :type => :buffer, :size => 100)
        log_replay.davis.frame.connect_to(mc_veo.frame, :type => :buffer, :size => 100)
        #log_replay.davis.depthmap.connect_to(mc_veo.depthmap, :type => :buffer, :size => 100)
        log_replay.davis.imu.connect_to(mc_veo.imu, :type => :buffer, :size => 100)
        log_replay.davis.poses.connect_to(mc_veo.groundtruth, :type => :buffer, :size => 100)
    elsif options[:log_type].casecmp("beamsplitter").zero?
        log_replay.camera_prophesee.events.connect_to(mc_veo.events, :type => :buffer, :size => 100)
        log_replay.camera_spinnaker.image_frame.connect_to(mc_veo.frame, :type => :buffer, :size => 100)
        log_replay.camera_prophesee.imu.connect_to(mc_veo.imu, :type => :buffer, :size => 100)
   end

    # Log mc-veo output ports
    Bundles.log_all

    # Configure the task
    mc_veo.configure

    # Run the task
    mc_veo.start

    # Manual control/stop of log replay (use for the "ceres" in atrium since the ceres backend takes very long time)
    #control = Vizkit.control log_replay
    #control.speed = 0.05
    #Vizkit.exec

    #puts log_replay.methods.sort (see all methods availables)
    # Automatic log replay
    while true
        if mc_veo.state == :RUNNING || mc_veo.state == :OPTIMIZING
            log_replay.step
            sleep_time = 0.005 # mc-veo is currently not real-time (this number migth change in your compute)
        elsif mc_veo.state == :INITIALIZING
            log_replay.step
            sleep_time = 0.001
        end
        if log_replay.eof?
            break
        end
        print "Log time: #{log_replay.time.to_hms} s:[#{sleep_time}]  TASK STATE: #{mc_veo.state}     \r"
        sleep(sleep_time)
    end
end
