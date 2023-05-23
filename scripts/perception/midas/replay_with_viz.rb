#!/usr/bin/env ruby

require 'rock/bundle'
require 'orocos/log'
require 'vizkit'
require 'readline'
require 'optparse'

include Orocos

options = {}
options[:logfile] = nil

op = OptionParser.new do |opt|
    opt.banner = <<-EOD
    dual_setup_visualization [options]
    EOD

    opt.on '--log=LOGFILE', String, 'path to the log file' do |log|
        options[:logfile] = log
    end

    opt.on '--help', 'this help message' do
        puts opt
        exit 0
    end
end

args = op.parse(ARGV)

# load log files and add the loaded tasks to the Orocos name service
log_replay = Orocos::Log::Replay.open(options[:logfile]) unless options[:logfile].nil?

Orocos::CORBA::max_message_size = 100000000000

## Initialize orocos ##
Bundles.initialize

viz_img = Vizkit.default_loader.ImageViewOld
viz_img.windowTitle = "MiDAS Depth Viz"

Orocos::Process.run 'midas::Task' => 'midas' do

    ## Get the task context ##
    midas = Orocos.name_service.get 'midas'

    # Logger
    logger = Orocos.name_service.get 'midas_Logger'
    logger.file = "midas.log"

    # Configure
    Orocos.conf.apply(midas, ['default'], :override => true)
    midas.configure

    # Connect ports
    #log_replay.camera_spinnaker.image_frame.connect_to midas.frame, :type => :buffer, :size => 10
    #log_replay.davis.frame.connect_to midas.frame, :type => :buffer, :size => 10
    log_replay.dsec.frame.connect_to midas.frame, :type => :buffer, :size => 10

    # Log the ports
    logger.log(midas.depthmap, 200)


    #Start the tasks
    midas.start

    # Start the logger
    #logger.start

    Vizkit.display midas.port("depthmap"), :widget => viz_img

    Vizkit.control log_replay 
    Vizkit.exec
end
