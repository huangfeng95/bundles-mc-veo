#!/usr/bin/env ruby

require 'rock/bundle'
require 'orocos/log'
require 'vizkit'

include Orocos

if !ARGV[0]
    STDERR.puts "usage: replay_wirth_viz <data_log_file>"
    exit 1
end

ENV['PKG_CONFIG_PATH'] = "#{File.expand_path("..", File.dirname(__FILE__))}/build:#{ENV['PKG_CONFIG_PATH']}"

Orocos::CORBA::max_message_size = 100000000000

## Initialize orocos ##
Bundles.initialize

tag_img = Vizkit.default_loader.ImageViewOld
tag_img.windowTitle = "AprilTag Viz"

Orocos::Process.run 'apriltags::Task' => 'apriltags',
                    'dual_setup::Task' => 'dual_setup' do

    ## Get the task context ##
    viz = Orocos.name_service.get 'dual_setup'
    tags = Orocos.name_service.get 'apriltags'

    ## Get the Apriltags Logger
    logger = Orocos.name_service.get 'apriltags_Logger'
    logger.file = "apriltags.0.log"

    # Configure
    Orocos.conf.apply(viz, ['default'], :override => true)
    Orocos.conf.apply(tags, ['default', "beamsplitter"], :override => true)
    viz.configure
    tags.configure

    #Logger task
    logger.log(tags.marker_poses, 100)
    logger.log(tags.single_marker_pose, 100)
    logger.log(tags.output_image, 100)

    # logs files
    log_replay = Orocos::Log::Replay.open( ARGV[0] )

    # Connect ports
    log_replay.camera_spinnaker.image_frame.connect_to viz.frame_in, :type => :buffer, :size => 100
    viz.frame.connect_to tags.image, :type => :buffer, :size => 100

    # Start the logger
    logger.start

    #Start the tasks
    viz.start
    tags.start

    Vizkit.display tags.port("output_image"), :widget => tag_img

    control = Vizkit.control log_replay
    control.speed = 1.0
    Vizkit.exec
end
